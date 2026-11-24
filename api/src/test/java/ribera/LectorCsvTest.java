package ribera;

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
    void comesDinsDeCometes() {
        List<Map<String, String>> f = LectorCsv.parseja("a,b\n\"Sueca, la Ribera\",x\n");
        assertEquals("Sueca, la Ribera", f.get(0).get("a"));
    }

    @Test
    void barraNEsNul() {
        List<Map<String, String>> f = LectorCsv.parseja("a,b\n\\N,\n");
        assertNull(f.get(0).get("a"));
        assertEquals("", f.get(0).get("b"));
    }

    @Test
    void filaAmbMassaColumnesFalla() {
        assertThrows(IllegalArgumentException.class, () -> LectorCsv.parseja("a,b\n1,2,3\n"));
    }
}
