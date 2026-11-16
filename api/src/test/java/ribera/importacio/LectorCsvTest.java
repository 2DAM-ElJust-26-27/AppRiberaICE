package ribera.importacio;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class LectorCsvTest {

    @Test
    void llegeixCapcaleraIFiles() {
        List<Map<String, String>> f = LectorCsv.parseja("codi,nom\nMUN01,Alberic\nMUN02,Alzira\n");
        assertEquals(2, f.size());
        assertEquals("Alberic", f.get(0).get("nom"));
    }

    @Test
    void cometesAmbComesICometesEscapades() {
        List<Map<String, String>> f = LectorCsv.parseja("a,b\n\"Sueca, la Ribera\",\"diu \"\"hola\"\"\"\n");
        assertEquals("Sueca, la Ribera", f.get(0).get("a"));
        assertEquals("diu \"hola\"", f.get(0).get("b"));
    }

    @Test
    void barraNEsNulICelaBuidaEsCadenaBuida() {
        List<Map<String, String>> f = LectorCsv.parseja("a,b,c\n\\N,,\"\\N\"\n");
        assertNull(f.get(0).get("a"));
        assertEquals("", f.get(0).get("b"));
        assertEquals("\\N", f.get(0).get("c"), "\\N entre cometes és text, no nul");
    }

    @Test
    void saltDeLiniaDinsDeCometesICrlf() {
        List<Map<String, String>> f = LectorCsv.parseja("a,b\r\n\"línia 1\nlínia 2\",x\r\n");
        assertEquals("línia 1\nlínia 2", f.get(0).get("a"));
        assertEquals("x", f.get(0).get("b"));
    }

    @Test
    void filaAmbColumnesIncorrectesFalla() {
        assertThrows(IllegalArgumentException.class, () -> LectorCsv.parseja("a,b\n1,2,3\n"));
    }

    @Test
    void sensSaltFinal() {
        assertEquals("2", LectorCsv.parseja("a\n1\n2").get(1).get("a"));
    }
}
