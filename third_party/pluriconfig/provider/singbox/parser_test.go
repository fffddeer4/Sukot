package singbox

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"net/url"
	"testing"

	box "github.com/getlantern/lantern-box"

	"github.com/getlantern/pluriconfig"
	_ "github.com/getlantern/pluriconfig/provider/url"
	"github.com/sagernet/sing-box/option"

	"github.com/getlantern/pluriconfig/model"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestParser_Parse(t *testing.T) {
	p := parser{}

	jsonData := []byte(`{
		"outbounds": [
			{
               "type": "shadowsocks",
               "tag": "ss-out",
               "server": "127.0.0.1",
               "server_port": 8388,
               "method": "chacha20-ietf-poly1305",
               "password": "randompasswordwith24char",
               "network": "tcp"
            }
		],
	}`)

	cfg, err := p.Parse(box.BoxContext(), jsonData)
	require.NoError(t, err, "Parse() error")

	assert.Equal(t, model.ProviderSingBox, cfg.Type)
	assert.Len(t, cfg.Options.(model.SingBoxOptions).Outbounds, 1)
	assert.Equal(t, "shadowsocks", cfg.Options.(model.SingBoxOptions).Outbounds[0].Type)
}

func TestParser_Serialize(t *testing.T) {
	p := parser{}
	ctx := box.BoxContext()
	expectedSSConfig := `{"outbounds": [{"tag": "ss-out", "type": "shadowsocks", "server": "127.0.0.1", "server_port": 8388, "method": "chacha20-ietf-poly1305", "password": "randompasswordwith24char"}]}`
	ssURL := url.URL{
		Scheme:   "ss",
		User:     url.User(base64.StdEncoding.EncodeToString([]byte("chacha20-ietf-poly1305:randompasswordwith24char"))),
		Host:     "127.0.0.1:8388",
		Fragment: "ss-out",
	}

	ssOutbound := model.Outbound{
		Name: "ss-out",
		Type: "shadowsocks",
		Options: model.ShadowsocksOutboundOptions{
			ServerOptions: model.ServerOptions{
				Server: "127.0.0.1",
				Port:   "8388",
			},
			Cipher:   "chacha20-ietf-poly1305",
			Password: "randompasswordwith24char",
		},
	}
	type args struct {
		ctx context.Context
		cfg *model.AnyConfig
	}
	var tests = []struct {
		name      string
		assert    func(t *testing.T, got []byte, err error)
		givenArgs args
	}{
		{
			name: "should return an error when the config provider is not supported",
			assert: func(t *testing.T, got []byte, err error) {
				assert.Error(t, err)
				assert.Nil(t, got)
			},
			givenArgs: args{
				ctx: ctx,
				cfg: &model.AnyConfig{
					Type: "unsupported",
				},
			},
		},
		{
			name: "should serialize a valid sing-box config successfully",
			assert: func(t *testing.T, got []byte, err error) {
				require.NoError(t, err)
				assert.JSONEq(t, expectedSSConfig, string(got))
			},
			givenArgs: args{
				ctx: ctx,
				cfg: &model.AnyConfig{
					Type: model.ProviderSingBox,
					Options: model.SingBoxOptions{
						Outbounds: []option.Outbound{
							{
								Type: "shadowsocks",
								Tag:  "ss-out",
								Options: option.ShadowsocksOutboundOptions{
									ServerOptions: option.ServerOptions{
										Server:     "127.0.0.1",
										ServerPort: 8388,
									},
									Method:   "chacha20-ietf-poly1305",
									Password: "randompasswordwith24char",
								},
							},
						},
					},
				},
			},
		},
		{
			name: "should return an error in case the provider is sing-box but options type is invalid",
			assert: func(t *testing.T, got []byte, err error) {
				assert.Error(t, err)
				assert.Nil(t, got)
			},
			givenArgs: args{
				ctx: ctx,
				cfg: &model.AnyConfig{
					Type:    model.ProviderSingBox,
					Options: "invalid-type",
				},
			},
		},
		{
			name: "should serialize a valid shadowsocks URL config successfully",
			assert: func(t *testing.T, got []byte, err error) {
				require.NoError(t, err)
				assert.JSONEq(t, expectedSSConfig, string(got))
			},
			givenArgs: args{
				ctx: ctx,
				cfg: &model.AnyConfig{
					Type:    model.ProviderURL,
					Options: []url.URL{ssURL},
				},
			},
		},
		{
			name: "should serialize a valid shadowsocks clash config successfully",
			assert: func(t *testing.T, got []byte, err error) {
				require.NoError(t, err)
				assert.JSONEq(t, expectedSSConfig, string(got))
			},
			givenArgs: args{
				ctx: ctx,
				cfg: &model.AnyConfig{
					Type:    model.ProviderClash,
					Options: []model.Outbound{ssOutbound},
				},
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			bytes, err := p.Serialize(tt.givenArgs.ctx, tt.givenArgs.cfg)
			tt.assert(t, bytes, err)
		})
	}
}

// TestParser_Serialize_VLESSWebSocketPathPreserved locks in the Sukot fix for
// URL-imported VLESS-over-WebSocket configs:
//   - the WebSocket path must be preserved VERBATIM (including "?ed=..." and
//     any server-side parameters such as "proxyip" that Cloudflare-Workers
//     servers read from the request path), and
//   - early data must NOT be derived from the path (the first payload goes in
//     a normal frame, which every server accepts), so max_early_data stays
//     unset, and
//   - an "ed" value followed by extra path parameters ("?ed=2048&proxyip=...")
//     must not blow up parsing (it used to fail with a ParseUint error, which
//     made such configs impossible to save).
func TestParser_Serialize_VLESSWebSocketPathPreserved(t *testing.T) {
	ctx := context.Background()
	p := parser{}

	raw := `vless://eead0cdf-bb4c-44b4-a953-7007b0dd7dd0@cf.example.workers.dev:443?path=%2F%3Fed%3D2048%26proxyip%3Dproxyip.example&security=tls&alpn=http%2F1.1&encryption=none&host=cf.example.workers.dev&fp=chrome&type=ws&allowInsecure=0&sni=cf.example.workers.dev#SUKOT-test`
	urlProvider, ok := pluriconfig.GetProvider(string(model.ProviderURL))
	require.True(t, ok)
	cfg, err := urlProvider.Parse(ctx, []byte(raw))
	require.NoError(t, err)

	got, err := p.Serialize(ctx, cfg)
	require.NoError(t, err)

	var parsed struct {
		Outbounds []map[string]interface{} `json:"outbounds"`
	}
	require.NoError(t, json.Unmarshal(got, &parsed))
	require.Len(t, parsed.Outbounds, 1)
	outbound := parsed.Outbounds[0]

	transport, ok := outbound["transport"].(map[string]interface{})
	require.True(t, ok, "expected a ws transport")
	assert.Equal(t, "ws", transport["type"])
	// Path preserved verbatim — nothing stripped, early data not moved out.
	assert.Equal(t, "/?ed=2048&proxyip=proxyip.example", transport["path"])
	_, hasEarlyData := transport["max_early_data"]
	assert.False(t, hasEarlyData, "max_early_data must not be set for path-embedded ed")

	tlsOpts, ok := outbound["tls"].(map[string]interface{})
	require.True(t, ok)
	assert.Equal(t, "cf.example.workers.dev", tlsOpts["server_name"])
}

// TestParser_Serialize_VLESSExplicitEdParam keeps explicit early data (a real
// "ed" query parameter outside the path) working, with the standard header.
func TestParser_Serialize_VLESSExplicitEdParam(t *testing.T) {
	ctx := context.Background()
	p := parser{}

	raw := `vless://eead0cdf-bb4c-44b4-a953-7007b0dd7dd0@cf.example.workers.dev:443?path=%2Fws&ed=2048&security=tls&type=ws&host=cf.example.workers.dev&sni=cf.example.workers.dev#ed-param`
	urlProvider, ok := pluriconfig.GetProvider(string(model.ProviderURL))
	require.True(t, ok)
	cfg, err := urlProvider.Parse(ctx, []byte(raw))
	require.NoError(t, err)

	got, err := p.Serialize(ctx, cfg)
	require.NoError(t, err)

	var parsed struct {
		Outbounds []map[string]interface{} `json:"outbounds"`
	}
	require.NoError(t, json.Unmarshal(got, &parsed))
	require.Len(t, parsed.Outbounds, 1)
	transport, ok := parsed.Outbounds[0]["transport"].(map[string]interface{})
	require.True(t, ok)
	assert.Equal(t, "/ws", transport["path"])
	assert.Equal(t, float64(2048), transport["max_early_data"])
	assert.Equal(t, "Sec-WebSocket-Protocol", transport["early_data_header_name"])
}
