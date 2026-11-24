package ribera;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/**
 * Importa les dades en una base de dades de proves i comprova el resultat
 * amb manifest.json i comprovacions.json. S'executa només si hi ha BD_PROVES_URL:
 *   BD_PROVES_URL=jdbc:postgresql://localhost:5432/ribera_proves mvn test
 * ATENCIÓ: esborra i torna a crear les taules d'aquesta base de dades.
 */
class ImportadorTest {

    /** Prepara una base de dades de proves amb les dades importades (també la usa ApiTest). */
    static void preparaBaseDades() throws Exception {
        String url = System.getenv("BD_PROVES_URL");
        assumeTrue(url != null && !url.isBlank(), "BD_PROVES_URL no definida");
        BaseDades.url = url;
        try (Connection c = BaseDades.connecta()) {
            c.createStatement().execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;");
            c.createStatement().execute(Files.readString(Path.of("../bd/01-esquema.sql")));
            new Importador(c, Path.of("../dades/sprint-1"), Path.of("../dades/complements")).importa();
        }
    }

    @BeforeAll
    static void prepara() throws Exception {
        preparaBaseDades();
    }

    @Test
    void elsRecomptesQuadrenAmbElManifest() throws SQLException {
        assertEquals(19, compta("entitat"));
        assertEquals(21, compta("centre"));
        assertEquals(29, compta("servei"));
        assertEquals(19, compta("prestacio"));
        assertEquals(11, compta("prestacio_centre"));
        assertEquals(9, compta("contacte"));
        assertEquals(19, compta("horari"));
        assertEquals(47, compta("municipi"));
    }

    @Test
    void disseteCentresTenenPunt() throws SQLException {
        assertEquals("17", BaseDades.textos("SELECT count(*) FROM centre WHERE latitud IS NOT NULL").get(0));
    }

    @Test
    void serveisPrestatsACullera() throws SQLException {
        // Mateix resultat que comprovacions.json
        assertEquals(List.of("SER12", "SER21", "SER23"), BaseDades.textos("""
                SELECT DISTINCT ii.codi_origen
                  FROM prestacio p
                  JOIN prestacio_centre pc ON pc.prestacio_id = p.id
                  JOIN centre c ON c.id = pc.centre_id
                  JOIN municipi m ON m.id = c.municipi_id
                  JOIN identitat_importacio ii ON ii.tipus_registre = 'servei' AND ii.registre_id = p.servei_id
                 WHERE m.nom = 'Cullera'
                 ORDER BY 1"""));
    }

    @Test
    void centresResidencialsDeSueca() throws SQLException {
        assertEquals(List.of("CEN01", "CEN04", "CEN08", "CEN09", "CEN13"), BaseDades.textos("""
                SELECT ii.codi_origen
                  FROM centre c
                  JOIN tipus_centre tc ON tc.id = c.tipus_centre_id
                  JOIN municipi m ON m.id = c.municipi_id
                  JOIN identitat_importacio ii ON ii.tipus_registre = 'centre' AND ii.registre_id = c.id
                 WHERE tc.codi = 'TC04' AND m.nom = 'Sueca'
                 ORDER BY 1"""));
    }

    private static int compta(String taula) throws SQLException {
        return Integer.parseInt(BaseDades.textos("SELECT count(*) FROM " + taula).get(0));
    }
}
