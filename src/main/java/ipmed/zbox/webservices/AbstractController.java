package ipmed.zbox.webservices;

import ipmed.zbox.entities.IpmedPublishedEntity;
import ipmed.zbox.repositories.MeasurementQueue;
import ipmed.zbox.services.AbstractService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.*;
import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.io.Serializable;
import java.lang.String;
import java.lang.StringBuilder;
import java.net.URISyntaxException;
import java.util.*;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;


/**
 *
 */
public abstract class AbstractController<T extends IpmedPublishedEntity & Serializable> {
    protected final static Logger LOG = Logger.getLogger(AbstractController.class.getName());

    static {
        LOG.setLevel(Level.FINEST);
    }

    @Autowired
    protected AbstractService<T> service;

    @Autowired
    protected MeasurementQueue queue;

    @RequestMapping(value = "", method = RequestMethod.GET, produces = "application/json; charset=utf-8")
    @ResponseBody
    public final Collection<T> findAll(@RequestParam(required = false) Long since) {
        if (since == null)
            return service.findAll();
        else
            return service.findAll(new Date(since));
    }

    @RequestMapping(value = "/notsent", method = RequestMethod.GET, produces = "application/json; charset=utf-8")
    @ResponseBody
    public final Collection<T> findAllNotSent() {
        return service.findAllNotSent();
    }

    @RequestMapping(value = "/{id}", method = RequestMethod.GET, produces = "application/json; charset=utf-8")
    @ResponseBody
    public final ResponseEntity<T> find(@PathVariable long id) {
        T entity = service.find(id);
        LOG.finer("Returning entity: " + entity);
        if (entity != null)
            return new ResponseEntity<>(entity, HttpStatus.OK);
        else
            return new ResponseEntity<>(HttpStatus.NOT_FOUND);
    }

    //changed to PUT (instead of PATCH) due to Android RestTemplate limitations!
    @RequestMapping(value = "/{id}", method = RequestMethod.PUT, produces = "application/json; charset=utf-8",
            consumes = "application/json")
    @ResponseBody
    public final ResponseEntity<T> update(@PathVariable long id, @RequestBody T newEntity)
            throws ReflectiveOperationException {
        System.out.println(newEntity);

        //Don't allow tries to change an entities id
        if (newEntity.getId()!=null && newEntity.getId()!=id){
            return new ResponseEntity<T>(HttpStatus.NOT_ACCEPTABLE);
        }

        T currentEntity = service.find(id);
        if (currentEntity == null) {
            return new ResponseEntity<T>(HttpStatus.NOT_FOUND);
        }

        newEntity.setId(id); //in case it was null (also acceptable) before
        newEntity = service.update(newEntity);
        return new ResponseEntity<>(newEntity, HttpStatus.OK);
    }

    @RequestMapping(value = "/{id}", method = RequestMethod.DELETE, produces = "application/json; charset=utf-8")
    @ResponseBody
    public final ResponseEntity<Void> delete(@PathVariable long id) {
        LOG.info("Got request("+this.getClass().getSimpleName()+"): delete" + id);
        service.delete(id);
        return new ResponseEntity<>(HttpStatus.NO_CONTENT);
    }

    /**
     * Pobieranie listy plików możliwych do załadowania przez API
     *
     * @return lista plików
     */
    protected ArrayList<String> _available_api_files() {
        ArrayList<String> files = new ArrayList<String>();
        try {
            File folder = new File(getClass().getResource("/api_files/").toURI());
            File[] listOfFiles = folder.listFiles();

            for (int i = 0; i < listOfFiles.length; i++) {
                if (listOfFiles[i].isFile())
                    files.add(listOfFiles[i].getName().split("\\.")[0]);
            }
        } catch(URISyntaxException e) {}

        return files;
    }

    /**
     * Pobieranie pliku z widokiem dla Web API
     *
     * @param name nazwa pliku do pobrania
     * @return treść pliku
     */
    protected String _load_api_file(final String name) {
        // Sprawdznie, czy to jest dozwolony plik
        if( ! _available_api_files().contains(name)) return "";

        InputStream is = getClass().getResourceAsStream("/api_files/"+name+".html");
        try( BufferedReader br = new BufferedReader(new InputStreamReader(is, "UTF-8")) ) {
            StringBuilder sb = new StringBuilder();
            String line = br.readLine();

            while (line != null) {
                sb.append(line);
                sb.append(System.lineSeparator());
                line = br.readLine();
            }
            return sb.toString();
        } catch(IOException e) {}

        return "";
    }

    @RequestMapping(value = "/webapi/{page}", method = RequestMethod.GET, produces = "application/json; charset=utf-8")
    @ResponseBody
    public Map<String, Object> webapiAll(@PathVariable String page, @RequestParam(required = false) Long since, @RequestParam(required = false) boolean just_data) {
        Collection<T> data = (since == null) ? service.findAll() : service.findAll(new Date(since));

        Map<String, Object> res = new HashMap<String, Object>();
        if(just_data) res.put("html", "");
        else res.put("html", _load_api_file(page));
        res.put("data", data);

        return res;
    }

}
