#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shellapi.h>
#include <cwchar>

#include "flutter_window.h"
#include "single_instance.h"
#include "utils.h"

namespace {

constexpr const wchar_t kSingleInstanceMutexName[] =
    L"Local\\org.getlantern.lantern.single-instance";
constexpr const wchar_t kSingleInstanceReadyEventName[] =
    L"Local\\org.getlantern.lantern.window-ready";
constexpr DWORD kWindowReadyTimeoutMs = 5000;
constexpr DWORD kActivationRetryTimeoutMs = 1000;
constexpr DWORD kActivationRetryIntervalMs = 100;

// True when the current process token holds the Administrators group (i.e.
// the app was launched elevated / "Run as administrator").
bool IsCurrentUserElevatedAdmin() {
  BOOL is_admin = FALSE;
  PSID admin_group = nullptr;
  SID_IDENTIFIER_AUTHORITY nt_authority = SECURITY_NT_AUTHORITY;
  if (!AllocateAndInitializeSid(&nt_authority, 2, SECURITY_BUILTIN_DOMAIN_RID,
                                DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0,
                                &admin_group)) {
    return false;
  }
  if (!CheckTokenMembership(nullptr, admin_group, &is_admin)) {
    is_admin = FALSE;
  }
  FreeSid(admin_group);
  return is_admin == TRUE;
}

// Returns true when another instance already owns the single-instance mutex.
// Probes without taking ownership so the caller can still decide to elevate.
bool IsAnotherInstanceRunning() {
  HANDLE probe = CreateMutexW(nullptr, FALSE, kSingleInstanceMutexName);
  if (probe == nullptr) {
    return false;
  }
  const bool already_running = GetLastError() == ERROR_ALREADY_EXISTS;
  CloseHandle(probe);
  return already_running;
}

// Relaunches this executable elevated ("Run as administrator" UAC prompt),
// forwarding any command-line arguments (deep links) to the new instance.
bool RelaunchElevated(const wchar_t *command_line) {
  wchar_t exe_path[MAX_PATH];
  if (GetModuleFileNameW(nullptr, exe_path, MAX_PATH) == 0) {
    return false;
  }
  // Strip argv[0] from the command line so only real arguments are forwarded.
  const wchar_t *args = command_line != nullptr ? command_line : L"";
  if (*args == L'"') {
    const wchar_t *end = wcschr(args + 1, L'"');
    if (end != nullptr) {
      args = end + 1;
    }
  } else {
    const wchar_t *space = wcschr(args, L' ');
    if (space != nullptr) {
      args = space;
    } else {
      args = args + wcslen(args);
    }
  }
  SHELLEXECUTEINFOW sei = {};
  sei.cbSize = sizeof(sei);
  sei.lpVerb = L"runas";
  sei.lpFile = exe_path;
  sei.lpParameters = args;
  sei.nShow = SW_SHOWNORMAL;
  return ShellExecuteExW(&sei) != FALSE;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // The VPN backend that ships inside the app creates the TUN adapter, which
  // Windows only allows to elevated processes. Before the single-instance
  // handoff, relaunch elevated unless an instance is already running (then
  // just activate it — no repeated UAC prompts) or the user declines.
  if (!IsCurrentUserElevatedAdmin()) {
    if (IsAnotherInstanceRunning()) {
      SingleInstanceReadyEvent window_ready(kSingleInstanceReadyEventName);
      window_ready.Wait(kWindowReadyTimeoutMs);
      return ActivateExistingLanternWindowWithRetry(kActivationRetryTimeoutMs,
                                                    kActivationRetryIntervalMs)
                 ? EXIT_SUCCESS
                 : EXIT_FAILURE;
    }
    if (RelaunchElevated(command_line)) {
      return EXIT_SUCCESS;
    }
    // Elevation declined or unavailable: keep running unelevated. Config
    // import, the server list and pings work; connecting will surface the
    // OS tunnel error.
  }

  SingleInstanceReadyEvent window_ready(kSingleInstanceReadyEventName);
  SingleInstanceLock single_instance(kSingleInstanceMutexName);
  if (!single_instance.IsPrimaryInstance()) {
    window_ready.Wait(kWindowReadyTimeoutMs);
    return ActivateExistingLanternWindowWithRetry(kActivationRetryTimeoutMs,
                                                  kActivationRetryIntervalMs)
               ? EXIT_SUCCESS
               : EXIT_FAILURE;
  }
  // If we acquire the mutex, start this build. Normal installer upgrades close
  // running Lantern instances before launch; handing off here could silently
  // keep a pre-single-instance build alive.

  // Ensure WebView2 uses a writable per-user data folder before the engine
  // (and any WebView2-backed plugin) starts. Otherwise production installs
  // under Program Files can't initialize WebView2 and in-app webviews go blank.
  EnsureWebView2UserDataFolder();

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"lantern", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  window_ready.Signal();

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
