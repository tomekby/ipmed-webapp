package ipmed.zbox.webservices;

import com.google.common.io.Resources;
import ipmed.zbox.entities.PatientEntity;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.io.*;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OptionalDataException;
import java.io.Reader;
import java.lang.ClassLoader;
import java.lang.Object;
import java.lang.String;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.charset.Charset;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.*;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.logging.Logger;

import static java.nio.file.Files.copy;
import java.util.stream.Collectors;


/**
 * Usługi udostępniające dane pacjentów
 */
@Controller
@RequestMapping("/patients")
public class PatientController extends AbstractController<PatientEntity> {

    private static Logger LOG = Logger.getLogger(PatientController.class.getName());

    @RequestMapping(value = "/{pid}/measurements/{mid}", method = RequestMethod.PUT, produces = "application/json; charset=utf-8",
            consumes = "application/json")
    @ResponseBody
    public ResponseEntity<Void> addMeasurement(@PathVariable long mid, @PathVariable long pid) {
        service.addPatientMeasurementRelation(mid, pid);
        return new ResponseEntity<>(HttpStatus.NO_CONTENT);
    }

    @ExceptionHandler
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public void handle(HttpMessageNotReadableException e) {
        LOG.info("Returning HTTP 400 Bad Request" + e.toString());
    }

    private static Object subsequentCreationLock = new Object();

    @RequestMapping(value = "", method = RequestMethod.POST, produces = "application/json; charset=utf-8",
            consumes = "application/json")
    @ResponseBody
    public ResponseEntity<PatientEntity> create(@RequestBody PatientEntity newEntity) {
        synchronized (subsequentCreationLock) {
            LOG.info("Got request: create new patient");
            LOG.fine("New patient: " + newEntity);

            if (newEntity.getId() != null) {
                LOG.info("Tried to create user with preassigned ID");
                return new ResponseEntity<>(HttpStatus.UNPROCESSABLE_ENTITY);
            }

            PatientEntity similar = service.getSimilar(newEntity);
            if (similar!=null)
                return new ResponseEntity<>(similar, HttpStatus.ALREADY_REPORTED);

//        newEntity = service.create(newEntity);
            newEntity = service.update(newEntity);
            return new ResponseEntity<>(newEntity, HttpStatus.CREATED);
        }
    }

    @Value("${dirwatcher.dir}")
    String watcherDir;

    //TODO: tylko do testow! Usunac na produkcji!
    @RequestMapping(value = "/kowalski", method = RequestMethod.GET)
    public ResponseEntity<Void> kowalski() {
        try {
            Path in = Paths.get(Resources.getResource("kowalski.csv").toURI());
            Path out = Paths.get(watcherDir, "kowalski.csv");
            LOG.finest("KOWALSKI from ");
            copy(in, out, StandardCopyOption.REPLACE_EXISTING);
            LOG.info("KOWALSKI moved.");
        } catch (Exception e) {
            LOG.severe("Can't move KOWALSKI file :((( " + e);
            return new ResponseEntity<>(HttpStatus.INTERNAL_SERVER_ERROR);
        }
        return new ResponseEntity<>(HttpStatus.OK);
    }

    @RequestMapping(value = "/ankieta/{id}", method = RequestMethod.GET, produces = "application/json; charset=utf-8")
    @ResponseBody
    public Map<String, Object> ankieta(@PathVariable long id, @RequestParam(required = false) Long since, @RequestParam(required = false) boolean just_data) {
        String page = "interview";
        List<PatientEntity> data = (since == null) ? service.findAll() : service.findAll(new Date(since));
        data = data.stream().filter(p -> p.getId() == id).collect(Collectors.toList());

        Map<String, Object> res = new HashMap<String, Object>();
        if(just_data) res.put("html", "");
        else res.put("html", _load_api_file(page));
        res.put("data", data.get(0));

        return res;
    }

    @RequestMapping(value = "/observation/{id}", method = RequestMethod.GET, produces = "application/json; charset=utf-8")
    @ResponseBody
    public Map<String, Object> observation(@PathVariable long id, @RequestParam(required = false) Long since, @RequestParam(required = false) boolean just_data) {
        String page = "observation";
        List<PatientEntity> data = (since == null) ? service.findAll() : service.findAll(new Date(since));
        data = data.stream().filter(p -> p.getId() == id).collect(Collectors.toList());

        Map<String, Object> res = new HashMap<String, Object>();
        if(just_data) res.put("html", "");
        else res.put("html", _load_api_file(page));
        res.put("data", data.get(0));

        return res;
    }

}
