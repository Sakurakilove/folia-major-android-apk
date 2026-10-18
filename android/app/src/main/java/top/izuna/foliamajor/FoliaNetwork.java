package top.izuna.foliamajor;

import com.getcapacitor.JSObject;
import java.net.*;

// Query Android's system proxy/PAC selector without involving a visible renderer.
final class FoliaNetwork {
    static JSObject resolve(String target) throws Exception {
        URI uri = URI.create(target);
        if (!"http".equals(uri.getScheme()) && !"https".equals(uri.getScheme())) throw new IllegalArgumentException("Unsupported network URL");
        ProxySelector selector = ProxySelector.getDefault();
        Proxy proxy = selector == null ? Proxy.NO_PROXY : selector.select(uri).get(0);
        JSObject route = new JSObject().put("type", proxy.type().name());
        if (proxy.address() instanceof InetSocketAddress) {
            InetSocketAddress address = (InetSocketAddress)proxy.address(); route.put("host", address.getHostString()).put("port", address.getPort());
        }
        return route;
    }
}
