package ribera.importacio;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.postgresql.ds.PGSimpleDataSource;
import ribera.bd.Jdbc;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.Statement;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/**
 * Proves d'integració contra un PostgreSQL de proves.
 * S'executen només si està definida la variable BD_PROVES_URL, p. ex.:
 *   BD_PROVES_URL=jdbc:postgresql://localhost:5432/ribera_proves mvn test
 * ATENCIÓ: la prova esborra i torna a crear l'esquema public d'aquesta base de dades.
 */
class ImportadorTest {

    private static final Path DADES = Path.of("../dades/sprint-1");
    private static final Path ESQUEMA = Path.of("../bd/01-esquema.sql");
    private static final Path COMPLEMENTS = Path.of("../dades/complements");
    private PGSimpleDataSource ds;

    @BeforeEach
    void basedadesNeta() throws Exception {
        String url = System.getenv("BD_PROVES_URL");
        assumeTrue(url != null && !url.isBlank(), "BD_PROVES_URL no definida: s'ometen les proves d'integració");
        ds = new PGSimpleDataSource();
        ds.setUrl(url);
        ds.setUser(System.getenv().getOrDefault("BD_USUARI", "ribera"));
        ds.setPassword(System.getenv().getOrDefault("BD_CONTRASENYA", "ribera"));
        try (Connection c = ds.getConnection(); Statement st = c.createStatement()) {
            st.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;");
            st.execute(Files.readString(ESQUEMA));
        }
    }

    @Test
    void carregaDesDeZeroQuadraAmbManifestIComprovacions() throws Exception {
        try (Connection c = ds.getConnection()) {
            InformeImportacio inf = new Importador(c, DADES).importa();
            assertTrue(inf.correcte(), inf.resum());
            assertTrue(inf.recomptesCorrectes(), inf.resum());
            assertTrue(inf.comprovacionsCorrectes(), inf.resum());
        }
    }

    @Test
    void repeticioNoDuplicaNiEsborraCorreccions() throws Exception {
        try (Connection c = ds.getConnection()) {
            assertTrue(new Importador(c, DADES).importa().correcte());
            // Correcció manual: completem un punt que a la font és nul
            Jdbc.executa(c, "UPDATE centre SET latitud = 39.2, longitud = -0.3 WHERE id = "
                    + "(SELECT registre_id FROM identitat_importacio WHERE tipus_registre = 'centre' AND codi_origen = 'CEN01')");

            InformeImportacio segona = new Importador(c, DADES).importa();
            assertTrue(segona.correcte(), segona.resum());
            assertTrue(segona.nous.isEmpty(), "La repetició no ha d'inserir res nou: " + segona.nous);
            assertTrue(segona.recomptesCorrectes(), segona.resum());
            assertEquals(1, Jdbc.compta(c, "SELECT count(*) FROM centre WHERE latitud = 39.2"),
                    "Un nul de la font no ha d'esborrar una correcció");
        }
    }

    @Test
    void referenciaInexistentInformaDelCamiIDesfaTot(@org.junit.jupiter.api.io.TempDir Path tmp) throws Exception {
        try (Stream<Path> s = Files.list(DADES)) {
            for (Path p : s.toList()) Files.copy(p, tmp.resolve(p.getFileName()));
        }
        Path serveis = tmp.resolve("serveis.json");
        Files.writeString(serveis, Files.readString(serveis).replaceFirst("\"centre_codi\": \"CEN05\"", "\"centre_codi\": \"CEN99\""));

        try (Connection c = ds.getConnection()) {
            InformeImportacio inf = new Importador(c, tmp).importa();
            assertFalse(inf.correcte());
            assertTrue(inf.errors.stream().anyMatch(e -> e.startsWith("serveis.json · serveis[")
                    && e.contains(".centres[0].centre_codi") && e.contains("CEN99")), inf.resum());
            assertEquals(0, Jdbc.compta(c, "SELECT count(*) FROM entitat"), "La importació fallida s'ha de desfer sencera");
        }
    }

    @Test
    void puntsComplementarisNomesOmplenCentresSensePunt() throws Exception {
        try (Connection c = ds.getConnection()) {
            InformeImportacio inf = new Importador(c, DADES, COMPLEMENTS).importa();
            assertTrue(inf.correcte(), inf.resum());
            assertTrue(inf.recomptesCorrectes() && inf.comprovacionsCorrectes(), inf.resum());
            assertEquals(16, inf.nous.get("punt_complementari"));
            assertEquals(17, Jdbc.compta(c, "SELECT count(*) FROM centre WHERE latitud IS NOT NULL"));
            // CEN05 conserva el punt publicat per la font inicial
            assertEquals("punt_publicat", Jdbc.un(c, "SELECT precisio_punt FROM centre WHERE id = "
                    + "(SELECT registre_id FROM identitat_importacio WHERE tipus_registre = 'centre' AND codi_origen = 'CEN05')",
                    rs -> rs.getString(1)).orElseThrow());
            // Els centres sense adreça continuen sense punt
            assertEquals(0, Jdbc.compta(c, "SELECT count(*) FROM centre ce JOIN identitat_importacio ii ON ii.registre_id = ce.id "
                    + "AND ii.tipus_registre = 'centre' WHERE ii.codi_origen IN ('CEN06','CEN14','CEN15','CEN21') AND ce.latitud IS NOT NULL"));

            // Correcció manual d'un punt complementari: la repetició no la sobreescriu
            Jdbc.executa(c, "UPDATE centre SET latitud = 39.3, longitud = -0.31 WHERE id = "
                    + "(SELECT registre_id FROM identitat_importacio WHERE tipus_registre = 'centre' AND codi_origen = 'CEN01')");
            InformeImportacio segona = new Importador(c, DADES, COMPLEMENTS).importa();
            assertTrue(segona.nous.isEmpty(), "Repetició sense canvis: " + segona.nous);
            assertEquals(1, Jdbc.compta(c, "SELECT count(*) FROM centre WHERE latitud = 39.3"));
        }
    }
}
