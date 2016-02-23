package ipmed.zbox.webservices;

import org.apache.http.HttpResponse;
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.UsernamePasswordCredentials;
import org.apache.http.client.CredentialsProvider;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.BasicCredentialsProvider;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;

import javax.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.util.logging.Logger;

@Controller
public class HomeController {
    private final static Logger LOG = Logger.getLogger(HomeController.class.getName());

    @RequestMapping(value = "/")
    public String home() {
        return "index";
    }

    /**
     * Próba zalogowania z podanymi danymi autentyfikacyjnymi
     * Konieczne ze względu na głupotę Chroma który przy HTTP 401 wyrzuca okienko autoryzacji...
     * @return HTTP 200 jeśli da się zalogować, co innego jeśli nie można
     */
    @RequestMapping(value = "/trylogin", method = RequestMethod.POST, consumes = "application/json")
    public ResponseEntity try_login(HttpServletRequest r, @RequestBody String[] auth_data) {
        String curr_url = r.getRequestURL().toString();
        String url = curr_url.substring(0, curr_url.lastIndexOf('/') + 1)+"support/ping";

        // Uwierzytelnianie i klient dla HTTP Basic Auth
        CredentialsProvider credsProvider = new BasicCredentialsProvider();
        credsProvider.setCredentials(
                new AuthScope(r.getServerName(), r.getServerPort()),
                new UsernamePasswordCredentials(auth_data[0], auth_data[1]));
        CloseableHttpClient client = HttpClients.custom()
                .setDefaultCredentialsProvider(credsProvider)
                .build();
        HttpGet request = new HttpGet(url);

        HttpResponse response;
        try {
            response = client.execute(request);
        } catch (IOException e) {
            // Coś poszło nie tak
            return new ResponseEntity(HttpStatus.I_AM_A_TEAPOT); // Co za różnica jaki tu header poleci?
        }

        LOG.fine("trylogin status code: " + response.getStatusLine().getStatusCode());
        return new ResponseEntity(HttpStatus.valueOf(response.getStatusLine().getStatusCode()));
    }
}