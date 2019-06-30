import core.BrowserException;
import modules.home.BizXHomePageActions;
import modules.login.BizXLoginActions;

import org.apache.log4j.Logger;
import org.testng.*;
import org.testng.annotations.*;
import org.testng.annotations.Parameters;
import java.net.MalformedURLException;

public class LoginTest extends LoginActions{
        final static Logger logger = Logger.getLogger(LoginTest.class);
        HomePageActions HomePage;

    @Parameters({"scope","environment", "seleniumenv","appheader","browser"})
    public LoginTest(String scope,String environment,String seleniumenv,String appheader,String browser) throws BrowserException{
        HomePage = Login(scope,environment,seleniumenv,appheader,browser);
    }

    @Test
    public void testLogin() {
        logger.info("Test :LoginTest");
        Assert.assertTrue(HomePage.isHomePageLoadedSuccessfull(),"Login Successfull");
    }

    @AfterTest
    public void tearDown() {
        shutdown();
    }
}
