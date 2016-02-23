package ipmed.zbox.webservices;

import ipmed.zbox.entities.MeasurementEntity;
import ipmed.zbox.services.MeasurementService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import java.util.logging.Logger;

/**
 * Usługi udostępniające dane pacjentów
 */
@Controller
@RequestMapping("/measurements")
public class MeasurementController extends AbstractController<MeasurementEntity> {

    private static Logger LOG = Logger.getLogger(MeasurementService.class.getName());

    @RequestMapping(value = "/{mid}/patient/{pid}", method = RequestMethod.PUT)
    @ResponseBody
    public ResponseEntity<Void> assignPatient(@PathVariable long mid, @PathVariable long pid) {
        service.addPatientMeasurementRelation(mid, pid);
        return new ResponseEntity<>(HttpStatus.NO_CONTENT);
    }

    //TODO: Tylko dla testów, metoda nie przewidziana później (nowe pomiary powstają z wrzucanych plików z założenia tylko)
    @RequestMapping(value = "", method = RequestMethod.POST, produces = "application/json; charset=utf-8",
            consumes = "application/json")
    @ResponseBody
    public ResponseEntity<MeasurementEntity> create(@RequestBody MeasurementEntity newEntity) {
        System.out.println(newEntity);
        //New entities cannot have ids preassigned
        if (newEntity.getId() != null) {
            return new ResponseEntity<>(HttpStatus.NOT_ACCEPTABLE);
        }
        newEntity = service.create(newEntity);
        return new ResponseEntity<>(newEntity, HttpStatus.CREATED);
    }

}
