package ribera.api;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.javalin.Javalin;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.postgresql.ds.PGSimpleDataSource;
import ribera.Aplicacio;
import ribera.importacio.Importador;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/** Proves de l'API sobre dades importades. Requereix BD_PROVES_URL (vegeu ImportadorTest). */
class ApiTest {

    private static Javalin app;
    private static String base;
    private static final HttpClient http = HttpClient.newHttpClient();
    private static final ObjectMapper om = new ObjectMapper();

    @BeforeAll
    static void arrenca() throws Exception {
        String url = System.getenv("BD_PROVES_URL");
        assumeTrue(url != null && !url.isBlank(), "BD_PROVES_URL no definida");
        PGSimpleDataSource ds = new PGSimpleDataSource();
        ds.setUrl(url);
        ds.setUser(System.getenv().getOrDefault("BD_USUARI", "ribera"));
        ds.setPassword(System.getenv().getOrDefault("BD_CONTRASENYA", "ribera"));
        try (Connection c = ds.getConnection(); Statement st = c.createStatement()) {
            st.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;");
            st.execute(Files.readString(Path.of("../bd/01-esquema.sql")));
            assertTrue(new Importador(c, Path.of("../dades/sprint-1")).importa().correcte());
        }
        app = Aplicacio.crea(ds).start(0);
        base = "http://localhost:" + app.port() + "/api/";
    }

    @AfterAll
    static void para() {
        if (app != null) app.stop();
    }

    private static HttpResponse<String> get(String ruta) throws Exception {
        return http.send(HttpRequest.newBuilder(URI.create(base + ruta)).build(), HttpResponse.BodyHandlers.ofString());
    }

    private static JsonNode json(String ruta) throws Exception {
        HttpResponse<String> r = get(ruta);
        assertEquals(200, r.statusCode(), ruta + " -> " + r.body());
        return om.readTree(r.body());
    }

    private static List<String> codis(JsonNode llista) {
        List<String> res = new ArrayList<>();
        llista.forEach(x -> res.add(x.get("codi").asText()));
        res.sort(null);
        return res;
    }

    private static long idMunicipi(String nom) throws Exception {
        for (JsonNode m : json("municipis")) if (m.get("nom").asText().equals(nom)) return m.get("id").asLong();
        throw new AssertionError("No trobat " + nom);
    }

    @Test
    void municipisICatalegs() throws Exception {
        assertEquals(47, json("municipis").size());
        JsonNode cat = json("catalegs");
        assertEquals(12, cat.get("collectius").size());
        assertEquals(9, cat.get("tipus_centre").size());
    }

    @Test
    void serveisPrestatsACulleraRecorrenPrestacioCentreMunicipi() throws Exception {
        assertEquals(List.of("SER12", "SER21", "SER23"), codis(json("serveis?municipi=" + idMunicipi("Cullera"))));
        assertEquals(List.of(), codis(json("serveis?collectiu=COL_SMG&municipi=" + idMunicipi("Cullera"))));
        assertEquals(List.of("SER16", "SER17"), codis(json("serveis?collectiu=COL_SMG&municipi=" + idMunicipi("Sueca"))));
    }

    @Test
    void centresResidencialsDeSuecaIMapa() throws Exception {
        assertEquals(List.of("CEN01", "CEN04", "CEN08", "CEN09", "CEN13"),
                codis(json("centres?tipus_centre=TC04&municipi=" + idMunicipi("Sueca"))));
        JsonNode mapa = json("centres?amb_punt=true");
        assertEquals(List.of("CEN05"), codis(mapa), "Només CEN05 té punt publicat");
        assertEquals(39.1615, mapa.get(0).get("latitud").asDouble(), 1e-6);
    }

    @Test
    void cercaSenseAccentsNiMajuscules() throws Exception {
        assertTrue(codis(json("serveis?q=ALZHEIMER")).contains("SER02"));
        assertTrue(codis(json("serveis?q=atencio%20majors")).contains("SER12"));
    }

    @Test
    void detallsIErrors() throws Exception {
        long idCen05 = json("centres?amb_punt=true").get(0).get("id").asLong();
        JsonNode centre = json("centres/" + idCen05);
        assertEquals("CEAM de Cullera", centre.get("nom").asText());
        assertEquals(List.of("SER12"), codis(centre.get("serveis")));

        long idServei = centre.get("serveis").get(0).get("id").asLong();
        JsonNode servei = json("serveis/" + idServei);
        assertEquals("ENT02", servei.get("prestacions").get(0).get("entitat").get("codi").asText());

        assertEquals(List.of("CEN05"), codis(json("centres?servei=" + idServei)), "Centres on es presta el servei");
        assertTrue(servei.has("collectius"));
        JsonNode resum = json("serveis?collectiu=COL_MAJORS");
        boolean ambTipus = false;
        for (JsonNode x : resum) if (x.get("codi").asText().equals("SER12"))
            ambTipus = x.get("tipus_centre").get(0).get("codi").asText().equals("TC06");
        assertTrue(ambTipus, "El resum de SER12 inclou el tipus del centre on es presta");

        assertEquals(404, get("centres/999999").statusCode());
        assertEquals(400, get("centres/abc").statusCode());
        assertEquals(400, get("serveis?municipi=abc").statusCode());
        assertEquals(400, get("centres?servei=abc").statusCode());
    }
}
