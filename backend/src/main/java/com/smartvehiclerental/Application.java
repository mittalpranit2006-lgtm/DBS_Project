package com.smartvehiclerental;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import com.smartvehiclerental.http.ApiController;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.Executors;

/** Same-origin static assets and direct-JDBC JSON API, bound to localhost. */
public final class Application {
    private static final Map<String, String> CONTENT_TYPES = Map.of(
            "/index.html", "text/html; charset=UTF-8",
            "/styles.css", "text/css; charset=UTF-8",
            "/app.js", "application/javascript; charset=UTF-8",
            "/api.js", "application/javascript; charset=UTF-8",
            "/ui.js", "application/javascript; charset=UTF-8");

    private Application() {}

    public static void main(String[] args) throws IOException {
        int port = Integer.parseInt(System.getenv().getOrDefault("SVR_HTTP_PORT", "8080"));
        if (port < 1 || port > 65535) throw new IllegalArgumentException("Invalid SVR_HTTP_PORT");
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", port), 0);
        server.createContext("/api/", new ApiController()::handle);
        server.createContext("/", Application::serveStatic);
        server.setExecutor(Executors.newFixedThreadPool(12));
        server.start();
        System.out.println("Smart Vehicle Rental server: http://127.0.0.1:" + port + "/");
    }

    private static void serveStatic(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        if (!method.equals("GET") && !method.equals("HEAD")) {
            respond(exchange, 405, "Method not allowed", "text/plain; charset=UTF-8");
            return;
        }
        String path = exchange.getRequestURI().getPath();
        if (path.equals("/")) path = "/index.html";
        String contentType = CONTENT_TYPES.get(path);
        if (contentType == null) {
            respond(exchange, 404, "Not found", "text/plain; charset=UTF-8");
            return;
        }
        try (InputStream input = Application.class.getResourceAsStream("/static" + path)) {
            if (input == null) {
                respond(exchange, 404, "Not found", "text/plain; charset=UTF-8");
                return;
            }
            byte[] body = input.readAllBytes();
            exchange.getResponseHeaders().set("Content-Type", contentType);
            exchange.getResponseHeaders().set("X-Content-Type-Options", "nosniff");
            exchange.sendResponseHeaders(200, method.equals("HEAD") ? -1 : body.length);
            if (!method.equals("HEAD")) {
                try (OutputStream output = exchange.getResponseBody()) {
                    output.write(body);
                }
            } else {
                exchange.close();
            }
        }
    }

    private static void respond(HttpExchange exchange, int status, String message, String contentType)
            throws IOException {
        byte[] body = message.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", contentType);
        exchange.sendResponseHeaders(status, body.length);
        try (OutputStream output = exchange.getResponseBody()) {
            output.write(body);
        }
    }
}
