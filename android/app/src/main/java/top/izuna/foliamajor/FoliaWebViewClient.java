package top.izuna.foliamajor;

import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebView;
import com.getcapacitor.Bridge;
import com.getcapacitor.BridgeWebViewClient;
import java.io.*;
import java.net.HttpURLConnection;
import java.util.*;

// Translate desktop media/mod origins to local authenticated protocol handlers, preserving Range streaming.
public class FoliaWebViewClient extends BridgeWebViewClient {
    private final Bridge foliaBridge;
    public FoliaWebViewClient(Bridge bridge) { super(bridge);foliaBridge=bridge; }
    @Override public boolean onRenderProcessGone(WebView view,android.webkit.RenderProcessGoneDetail detail){
        return FoliaWindowHost.rendererGone((MainActivity)foliaBridge.getActivity(),view);
    }

    @Override
    public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
        WebResourceResponse response = interceptProtocol(request);
        return response != null ? response : super.shouldInterceptRequest(view, request);
    }

    static WebResourceResponse interceptProtocol(WebResourceRequest request) {
        String host = request.getUrl().getHost();
        if (host != null) for (String scheme : new String[]{"folia-mod", "folia-cover", "folia-transcode", "folia-ytm", "folia-spotify"}) {
            String suffix = "." + scheme + ".localhost";
            if (!host.endsWith(suffix) || !"GET".equals(request.getMethod())) continue;
            String originalHost = host.substring(0, host.length() - suffix.length());
            String target = scheme + "://" + originalHost + request.getUrl().getEncodedPath();
            if (request.getUrl().getEncodedQuery() != null) target += "?" + request.getUrl().getEncodedQuery();
            try {
                HttpURLConnection connection = FoliaRuntimePlugin.openProtocol(target, request.getRequestHeaders());
                int status = connection.getResponseCode();
                String contentType = connection.getContentType();
                String mime = contentType == null ? "application/octet-stream" : contentType.split(";")[0];
                Map<String, String> headers = new HashMap<>();
                for (Map.Entry<String, List<String>> header : connection.getHeaderFields().entrySet()) {
                    if (header.getKey() != null) headers.put(header.getKey(), String.join(", ", header.getValue()));
                }
                InputStream source = status < 400 ? connection.getInputStream() : connection.getErrorStream();
                InputStream stream = new FilterInputStream(source == null ? new ByteArrayInputStream(new byte[0]) : source) {
                    @Override public void close() throws IOException { try { super.close(); } finally { connection.disconnect(); } }
                };
                String reason = connection.getResponseMessage();
                return new WebResourceResponse(mime, "UTF-8", status, reason == null || reason.isEmpty() ? "Response" : reason, headers, stream);
            } catch (Exception error) {
                return new WebResourceResponse("text/plain", "UTF-8", 502, "Local protocol unavailable", Collections.emptyMap(),
                    new ByteArrayInputStream("Local protocol unavailable".getBytes(java.nio.charset.StandardCharsets.UTF_8)));
            }
        }
        return null;
    }
}
