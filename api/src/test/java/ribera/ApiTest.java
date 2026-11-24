package ribera;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.javalin.Javalin;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import static org.junit.jupiter.api.Assertions.*;

/** Fa peticions reals a l'API. Requereix BD_PROVES_URL (vegeu ImportadorTest). */
class ApiTest {

    private static Javalin app;
    private static final HttpClient http = HttpClient.newHttpClient();

    @BeforeAll
    static void arranca() throws Exception {
        ImportadorTest.preparaBaseDades();
        app = Aplicacio.crea().start(0);   // port 0 = qualsevol port lliure
    }

    @AfterAll
    static void para() {
        if (app != null) app.stop();
    }

    private static HttpResponse<String> get(String ruta) throws Exception {
        URI uri = URI.create("http://localhost:" + app.port() + ruta);
        return http.send(HttpRequest.newBuilder(uri).build(), HttpResponse.BodyHandlers.ofString());
    }

    private static JsonNode json(String ruta) throws Exception {
        return new ObjectMapper().readTree(get(ruta).body());
    }

    @Test
    void llistesSenceres() throws Exception {
        assertEquals(21, json("/api/centres").size());
        assertEquals(29, json("/api/serveis").size());
        assertEquals(19, json("/api/entitats").size());
    }

    @Test
    void serveisPrestatsACullera() throws Exception {
        // Cerquem l'id del municipi Cullera a la base de dades
        String id = BaseDades.textos("SELECT id FROM municipi WHERE nom = 'Cullera'").get(0);
        assertEquals(3, json("/api/serveis?municipi=" + id).size());
    }

    @Test
    void fitxaDeCentreAmbServeis() throws Exception {
        String id = BaseDades.textos("""
                SELECT registre_id FROM identitat_importacio
                 WHERE tipus_registre = 'centre' AND codi_origen = 'CEN05'""").get(0);
        JsonNode centre = json("/api/centres/" + id);
        assertTrue(centre.get("serveis").size() > 0);
        assertTrue(centre.get("latitud").isNumber());
    }

    @Test
    void errors404i400() throws Exception {
        assertEquals(404, get("/api/centres/999999").statusCode());
        assertEquals(400, get("/api/centres/abc").statusCode());
    }
}
