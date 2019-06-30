package core;

import java.util.concurrent.TimeUnit;

import org.apache.log4j.Logger;
import org.openqa.selenium.Alert;
import org.openqa.selenium.By;
import org.openqa.selenium.Capabilities;
import org.openqa.selenium.NoSuchElementException;
import org.openqa.selenium.OutputType;
import org.openqa.selenium.TakesScreenshot;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import java.net.URL;
import java.io.*;
import org.openqa.selenium.Proxy;
import org.apache.commons.io.FileUtils;
import java.util.*;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

import org.ini4j.Profile.Section;
import org.ini4j.*;
import org.apache.commons.io.FilenameUtils;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.support.events.EventFiringWebDriver;
import org.openqa.selenium.support.ui.ExpectedCondition;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.FluentWait;
import org.openqa.selenium.support.ui.Select;
import org.openqa.selenium.support.ui.WebDriverWait;
import org.testng.ITestResult;

//import com.paulhammant.ngwebdriver.ByAngular;
//import com.paulhammant.ngwebdriver.NgWebDriver;

import org.openqa.selenium.remote.*;
import org.openqa.selenium.remote.DesiredCapabilities;
import org.openqa.selenium.remote.RemoteWebDriver;
import org.openqa.selenium.edge.*;
import org.openqa.selenium.firefox.FirefoxDriver;  
import org.openqa.selenium.firefox.FirefoxProfile;
import org.openqa.selenium.interactions.Actions;
import org.openqa.selenium.JavascriptExecutor;
import org.openqa.selenium.NoAlertPresentException;

import java.net.MalformedURLException;
import org.openqa.selenium.remote.html5.RemoteLocalStorage;
import org.openqa.selenium.WebDriverException;

public class MainBrowser {
	static private RemoteWebDriver driver;	
	final static Logger logger = Logger.getLogger(MainBrowser.class);
	
	//private NgWebDriver ngWebDriver;
	public void initBrowser(String url,String header,String browser,String proxy) throws MainBrowserException
	{							
		try {
			URL urlObj = new URL(url);	
			DesiredCapabilities capa = setCapabilities(browser,header,proxy);			  	 					
			driver=launchDriver(urlObj,capa);					
			logger.info("Driver launched");
			driver.manage().timeouts().implicitlyWait(120, TimeUnit.SECONDS);
			driver.manage().timeouts().setScriptTimeout(30, TimeUnit.SECONDS);				
			driver.manage().window().maximize();				
			driver.switchTo().defaultContent();				
			logSystemDetails();
			logger.info("After log details");
			if (browser.equals("gc")) {
				logger.info("Insige gc");
				setChromeProfile(header);
			}		
		}catch(Throwable e) {
			logger.info("Failures in initBrowser");
			throw new MainBrowserException("initBrowser initialization failed",e);
		}
	}


	// Launch RemoteWebDrivr with retry mechanism 
	public RemoteWebDriver launchDriver(URL urlObj,DesiredCapabilities capa) throws java.lang.InterruptedException,  java.lang.RuntimeException{
		logger.info("inside launchDriver method");
		int count=0;
		int retryCount=3;			
		while ( count <= retryCount ) {
            try{
               return new RemoteWebDriver(urlObj,capa);	                             
            }
            catch(Throwable e){
            	logger.info("Count=" + count + ".Failed to launch");
                Thread.sleep(60000);
                count++;                
            }            
        }
        throw new java.lang.RuntimeException("Unable to Launch browser due to exception after 3 attemps");    
	}


	// Read Properties files
	public Ini readPropertiesFile(String propFileName) throws IOException {		
		InputStream inputStream=null;		

		Ini props = new Ini();
		try { 							
			inputStream = getClass().getClassLoader().getResourceAsStream(propFileName); 			
			if (inputStream != null) {
				props.load(inputStream);
			} else {
				throw new FileNotFoundException("property file '" + propFileName + "' not found in the classpath");
			} 			
 		} catch (Exception e) {
 			System.out.println("Exception: " + e);
		} finally {
			inputStream.close();
		}
		return props;
	}


	public void logSystemDetails(){
		Capabilities caps = ((RemoteWebDriver) driver).getCapabilities();
	    String browserName = caps.getBrowserName();
		String browserVersion = caps.getVersion();
        String os = System.getProperty("os.name").toLowerCase();
        logger.info("OS = " + os + ", Browser = " + browserName + " "+ browserVersion);
	}

	public DesiredCapabilities setCapabilities(String browser,String header,String proxy) throws java.io.IOException {
		DesiredCapabilities capa=null;
		if (browser.equals("ff")) {
			capa = DesiredCapabilities.firefox();  
			((DesiredCapabilities) capa).setBrowserName("firefox");			
 			((DesiredCapabilities) capa).setPlatform(org.openqa.selenium.Platform.ANY);
 			FirefoxProfile profile = setFireFoxProfile(header); 			
			((DesiredCapabilities) capa).setCapability(FirefoxDriver.PROFILE, profile);	
			logger.info("Updated FireFox catapabilities");
		}else if (browser.equals("gc")){
			ChromeOptions options=new ChromeOptions();	

			//options.addArguments("disable-extensions");				
			options.addExtensions(new File("ModHeader_v2.1.1.crx"));				
  	 		capa = DesiredCapabilities.chrome(); 
  	 		if (proxy.equals("true")) {
  	 			logger.info("Using Proxy");
  	 			Proxy proxyobj = new Proxy();
				proxyobj.setSslProxy("proxy.wdf.sap.corp:8080");
				proxyobj.setHttpProxy("proxy.wdf.sap.corp:8080");
  	 			capa.setCapability(CapabilityType.PROXY, proxyobj);  	 			
  	 		}
  	 		capa.setCapability(ChromeOptions.CAPABILITY, options);
  	 		logger.info("Updated Chrome catapabilities");
                }else if (browser.equals("edge")) {
                         capa = DesiredCapabilities.edge();
                        ((DesiredCapabilities) capa).setBrowserName("MicrosoftEdge");
                        ((DesiredCapabilities) capa).setPlatform(org.openqa.selenium.Platform.ANY);
			 logger.info("Update Edge");
		}else {
			logger.info(browser+" Browser is not supported, Only GC , Edge and FF are supported");
		}
		return capa;
	}

	public void setChromeProfile(String header)
	{		
		//dummy login to be able to update the local storage
		driver.get("http://www.google.co.il");
		driver.get("chrome-extension://idgpnmonknjnojddfkpgkljpfnnfcklj/settings.tmpl.html");
		ExecuteMethod executeMethod =new RemoteExecuteMethod(driver);
		RemoteLocalStorage lstorage =new RemoteLocalStorage(executeMethod);			
		String json = "[{\"title\":\"Profile 1\",\"hideComment\":true,\"headers\":[{\"enabled\":true,\"name\":\"testapplication\",\"value\":\"" + header + "\",\"comment\":\"\"}],\"respHeaders\":[],\"filters\":[],\"appendMode\":\"\"}]";					
		lstorage.setItem("profiles",json);	
		logger.info("Enabled http headers for chrome");	
	}	

	public FirefoxProfile setFireFoxProfile(String header) throws java.io.IOException{
		FirefoxProfile profile = new FirefoxProfile();
		File modifyHeaders = new File("modify_headers-0.7.1.1-fx.xpi");
  		profile.setEnableNativeEvents(false);   		
  		profile.addExtension(modifyHeaders); 		  		
  		profile.setPreference("modifyheaders.headers.count", 1);
   		profile.setPreference("modifyheaders.headers.action0", "Add");
   		profile.setPreference("modifyheaders.headers.name0", "testapplication");
   		profile.setPreference("modifyheaders.headers.value0", header);
   		profile.setPreference("modifyheaders.headers.enabled0", true);
   		profile.setPreference("modifyheaders.config.active", true);
   		profile.setPreference("modifyheaders.config.alwaysOn", true);
   		logger.info("Enabled http headers for firefox");	
   		return profile;
	}


	public void init(String seleniumenv,String header, String browser,String proxy)  throws  MainBrowserException{				
		Ini prop=null;
		Section section=null;
		String seleniumUrl=null;
		String seleniumprop = "selenium/selenium.ini";	
		try {
			prop=readPropertiesFile(seleniumprop);
			section = prop.get(seleniumenv);	
			seleniumUrl=section.get("seleniumUrl");									
		}catch(Exception ex) {
			logger.error("Cannot get Section " + seleniumenv + " from " + seleniumprop);
			System.exit(1);
		}			
		logger.info("SeleniumUrl=" + seleniumUrl);		
		initBrowser(seleniumUrl,header,browser,proxy);		
	}
	
	public RemoteWebDriver gerDriver(){
		return driver;
		
	}
	
	public void navigateTo(String url){
		driver.get(url);
		
	}

	public void screenShot() {
		 try{		 
			 TakesScreenshot screenshot=(TakesScreenshot)driver;
			 File src=screenshot.getScreenshotAs(OutputType.FILE);
			 FileUtils.copyFile(src,new File(System.getProperty("user.dir") + "/TestScreenShot.png"));		
			 System.out.println("Successfully captured a screenshot");
		 }catch (Exception e){
			 System.out.println("Exception while taking screenshot "+e.getMessage());
		 } 		 		 
	}
	
	public void shutdown() {	
		logger.info("Running driver.quit");
		driver.quit();
	}
	
	public void sleep(long timeout) {
		try {
			Thread.sleep(timeout);
		} catch (InterruptedException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}

	public void waitForElementInVisibility(String xpath){
		WebDriverWait wait = new WebDriverWait(driver, 200);
        wait.until(ExpectedConditions.invisibilityOfElementLocated(By.xpath(xpath)));
	}
	public void waitForElementInVisibility(String xpath,int timeout){
		WebDriverWait wait = new WebDriverWait(driver, timeout);
        wait.until(ExpectedConditions.invisibilityOfElementLocated(By.xpath(xpath)));
	}
	public void waitForElementToBeClickable(String ID){
		try {
			WebDriverWait wait = new WebDriverWait(driver, 50);
			wait.until(ExpectedConditions.elementToBeClickable((By.id(ID))));
		}catch(WebDriverException ex) {
			logger.error("Element not clickable after timeout. error=" + ex.getMessage());
			screenShot();
			throw new MainBrowserException("Element not clickable even after timeout",ex);
		}
	}

 public void waitForElementClickableCSS(String css){		
        try {
        	FluentWait<WebDriver> wait = new FluentWait<WebDriver>(driver)
      		      .withTimeout(10, TimeUnit.SECONDS)
      		      .pollingEvery(5, TimeUnit.SECONDS)
      		      .ignoring(NoSuchElementException.class);	
              wait.until(ExpectedConditions.elementToBeClickable(By.cssSelector(css)));				
		}catch(WebDriverException ex){
			logger.error("Element not clickable even after timeout. Error=" + ex.getMessage());
			screenShot();
			throw new MainBrowserException("Element not clickable even after timeout",ex);
		}
	}

	public void waitForElementClickable(String xpath){		
        try {
        	FluentWait<WebDriver> wait = new FluentWait<WebDriver>(driver)
      		      .withTimeout(60, TimeUnit.SECONDS)
      		      .pollingEvery(5, TimeUnit.SECONDS)
      		      .ignoring(NoSuchElementException.class);	
              if(xpath.startsWith("//") || xpath.startsWith("(//")){
      			wait.until(ExpectedConditions.elementToBeClickable(By.xpath(xpath)));
      		}else{
      			wait.until(ExpectedConditions.elementToBeClickable(By.id(xpath)));
      		}
		}catch(WebDriverException ex){
			logger.error("Element not clickable even after timeout. Error=" + ex.getMessage());
			screenShot();
			throw new MainBrowserException("Element not clickable even after timeout",ex);
		}
	}

	public void waitForElementVisibility(String xpath){
		try {
			FluentWait<WebDriver> wait = new FluentWait<WebDriver>(driver)
			      .withTimeout(90, TimeUnit.SECONDS)
			      .pollingEvery(5, TimeUnit.SECONDS)
			      .ignoring(NoSuchElementException.class);	
		 	//WebDriverWait wait = new WebDriverWait(driver, 120);'
			if(xpath.startsWith("//") || xpath.startsWith("(//")){
				wait.until(ExpectedConditions.visibilityOfElementLocated(By.xpath(xpath)));
			}else{
				wait.until(ExpectedConditions.visibilityOfElementLocated(By.id(xpath)));
			}
		}catch(Exception e) {
			logger.error("waitForElementVisibility Exception=" + e.getMessage());
			screenShot();
			throw new MainBrowserException("exception on waiting for element visibility",e);
		}
	}

	public void switchToiFrame(String iframe){		
		driver.switchTo().frame(findElementByXpath(iframe));		
	}
	public void switchToWindow(String windowName){
		boolean foundFlag=false;
		waitForWindowToAppear();
		Set<String> winhandles = driver.getWindowHandles();
		for(String handle:winhandles){
			if(driver.switchTo().window(handle).getTitle().contains(windowName)){
				driver.switchTo().window(handle);
				foundFlag=true;
			}
		}
		if(foundFlag){
			logger.info("Switched to window: "+windowName+" Successfully");
		}else{
			logger.info("Switched to window"+windowName+" failed, No window found with the name:"+windowName);
			
		}
			
	}
	public void waitForWindowToAppear(){
		boolean winOpen=false;
		int counter=1;
		do{
			if((driver.getWindowHandles().size())==2){
				winOpen=true;
			}else{
				++counter;
			}
		}while(!winOpen && counter==60);
	}
	public void switchToDefaultContent(){		
		driver.switchTo().defaultContent();	
	}
	public WebElement findElementByID(String elementID){
		WebElement element=null;
		try {
			element=driver.findElement(By.id(elementID));				
		}catch(WebDriverException ex){
			logger.error("Unable to find Element By given ID. Error=" + ex.getMessage());
			screenShot();
			throw new MainBrowserException("Unable to find Element By given ID",ex);
		}
		return element;		
	}

	public WebElement findElementByCSS(String css){	
		WebElement element=null;
		try {
			element=driver.findElement(By.cssSelector(css));				
		}catch(WebDriverException ex){
			logger.error("Unable to find Element By Xpath. Error=" + ex.getMessage());
			screenShot();
			throw new MainBrowserException("Unable to find Element By given CSS",ex);
		}
		return element;
	}

	public WebElement findElementByXpath(String xpath){	
		WebElement element=null;
		try {
			element=driver.findElement(By.xpath(xpath));				
		}catch(WebDriverException ex){
			logger.error("Unable to find Element By Xpath. Error=" + ex.getMessage());
			screenShot();
			throw new MainBrowserException("Unable to find Element By given xpath",ex);
		}
		return element;
	}
	public int getElementCountByXpath(String xpath){
		return driver.findElements(By.xpath(xpath)).size();
	}
	
	public void clickElementByCSS(String css)
	{		
		WebElement element = findElementByCSS(css);
		if(element!=null){
			try{
				element.click();
			}catch(WebDriverException ex){
				logger.error("Unable to click on element. Error=" + ex.getMessage());
				screenShot();
				throw new MainBrowserException("Unable to click Element By given CSS",ex);
			}
		}else{
			shutdown();
			System.exit(0);
		}
 	}

    
	public void clickElementByXpath(String xpath)
	{
		//driver.findElement(By.xpath(xpath)).click();	
		WebElement element = findElementByXpath(xpath);
		if(element!=null){
			try{
				element.click();
			}catch(WebDriverException ex){
				logger.error("Unable to click on element. Error=" + ex.getMessage());
				screenShot();
			}
		}else{
			shutdown();
			System.exit(0);
		}
 	}
	public void select(String locator,String text){
		logger.info("Selecting option:"+text+" for the select element with locator:"+locator);
		Select select;
		if(locator.startsWith("//")){
			 select = new Select(findElementByXpath(locator));
		}else{
			 select = new Select(findElementByID(locator));
		}
		//select.deselectAll();
		select.selectByVisibleText(text);
	}
	public void selectByIndex(String locator,int index){
		logger.info("Selecting option index:"+index+" for the select element with locator:"+locator);
		Select select;
		if(locator.startsWith("//")){
			 select = new Select(findElementByXpath(locator));
		}else{
			 select = new Select(findElementByID(locator));
		}
		//select.deselectAll();
		select.selectByIndex(index);
	}
 	public void executeScript(String scriptpath) { 		
		((JavascriptExecutor)driver).executeScript(scriptpath);	 	
 	}
 	public void executeScript(String scriptpath, WebElement element) { 		
		((JavascriptExecutor)driver).executeScript(scriptpath,element);	 	
 	}
 	public String executeSyncScript(String scriptpath) { 		
		String result = null;
		try{
			result = (String) driver.executeScript(scriptpath);
			
		}catch(WebDriverException e){
			logger.fatal("Unable to execute sync script:"+e);
			shutdown();
			throw e;
		}
		
		return result;
 	}
 	
 	

	public void enterText(String locator,String text){
		logger.info("Enter text:"+text+" for the edit element with locator:"+locator);
		WebElement element = null;
		if(locator.startsWith("//")){
			element = findElementByXpath(locator);
		}else{
			element = findElementByID(locator);
		}
		
		if(element!=null){
			try{
				element.clear();
				element.sendKeys(text);		
			}catch(WebDriverException ex){
				logger.error("Unable to enter text. Error=" + ex.getMessage());
				screenShot();
			}
		}else{
			logger.error("Cannot find element " + locator);
			shutdown();
			System.exit(0);
		}
		
	}
	public String getText(String xpath){
		logger.info("Get text from element with locator:"+xpath);
		WebElement element = findElementByXpath(xpath);
		if(element!=null){
			try{
				return element.getText();		
			}catch(WebDriverException ex){
				logger.error("Unable to get text. Error=" + ex.getMessage());
				screenShot();
				return null;
			}
		}else{
			shutdown();
			System.exit(0);
		}
		return null;
		
	}

	public void click(String elementID){
		logger.info("Click on element with locator:"+elementID);
		WebElement element = findElementByID(elementID);	
		if(element!=null){
			try	 {				
				waitForElementToBeClickable(elementID);				
				element.click();					
			}catch(WebDriverException ex) {
				logger.error("Unable to click on element" + elementID + " Error=" + ex.getMessage());
				screenShot();
			}
		}else{
			logger.error("Cannot find element  " + elementID);
			shutdown();
			System.exit(0);
		}		
	}

	public void waitForMainPageToLoad() {
		logger.info("wait for main page to finish loading");
		waitForElementInVisibility("//*[@id='120:']");
	}
	public void waitForAngularPageToLoad() {
		logger.info("wait for Angular page to finish loading");
		//ngWebDriver = new NgWebDriver(driver);
		//ngWebDriver.waitForAngularRequestsToFinish();
		WebDriverWait wait = new WebDriverWait(driver, 200);
	    wait.until(ExpectedConditions.visibilityOfElementLocated(By.xpath("//div[@class='spinner']")));
	    wait.until(ExpectedConditions.invisibilityOfElementLocated(By.xpath("//div[@class='spinner']")));
	}
	/*
	 clickElementByAngularText is used for clicking angular elements based on text, It works only with AngularJS controls
	 
	 Input- Elemetn text ex: Button text 'Sing in' etc
	 */
		public void clickElementByAngularText(String elementText)
		{		
			WebElement element = findElementByAngularText(elementText);
			if(element!=null){
				try{
					element.click();
				}catch(WebDriverException ex){
					logger.error("Unable to click on element. Error=" + ex.getMessage());
					screenShot();
					throw new MainBrowserException("Unable to click Element By given Angular Text",ex);
				}
			}else{
				shutdown();
				System.exit(0);
			}
	 	}
		public WebElement findElementByAngularText(String elementText){	
			WebElement element=null;
			try {
				//element=driver.findElement(ByAngular.buttonText(elementText));				
			}catch(WebDriverException ex){
				logger.error("Unable to find Element By Xpath. Error=" + ex.getMessage());
				screenShot();
				throw new MainBrowserException("Unable to find Element By given Angular Text",ex);
			}
			return element;
		}
	public void waitForPageToLoad() {
		logger.info("wait for page to finish loading");
		try {
			
			Thread.sleep(2000);
		} catch (InterruptedException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}
	public boolean waitForJStoLoad() {
		try {
			Thread.sleep(10000);
		} catch (InterruptedException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

	    WebDriverWait wait = new WebDriverWait(driver, 60);

	    // wait for jQuery to load
	    ExpectedCondition<Boolean> jQueryLoad = new ExpectedCondition<Boolean>() {
	      @Override
	      public Boolean apply(WebDriver driver) {
	        try {
	          return (executeSyncScript("return jQuery.active").equals("0"));
	        }
	        catch (Exception e) {
	          return true;
	        }
	      }
	    };

	    ExpectedCondition<Boolean> jsLoad = new ExpectedCondition<Boolean>() {
	      @Override
	      public Boolean apply(WebDriver driver) {
	        return executeSyncScript("return document.readyState")
	            .toString().equals("complete");
	      }
	    };

	  return wait.until(jQueryLoad) && wait.until(jsLoad);
	}
	public void clickByXpathAfterLoad(String xpath){	
		logger.info("Click on element with locator:"+xpath);
		waitForMainPageToLoad();
		logger.info("xpath=" + xpath);  											
		clickByXpath(xpath);		
	}

	public void clickByCSS(String css){
		logger.info("Click on element with locator:"+css);
		waitForElementClickableCSS(css);      											
		clickElementByCSS(css);			
	}

	public void clickByXpath(String xpath){
		waitForElementClickable(xpath);    
		logger.info("xpath=" + xpath);  											
		clickElementByXpath(xpath);	
		
	}
	
	public boolean elementExists(String locator){		
		boolean found=false;
		try{
			waitForElementVisibility(locator);
			WebElement element; //= findElementByXpath(locator);
			if(locator.startsWith("//")){
				element = findElementByXpath(locator);
			}else{
				element = findElementByID(locator);
			}
			if (element != null){
				found=element.isDisplayed();
			}
			return found;
		}catch(Exception e){
			logger.error("Element not found on the page:" + e.getMessage());
			screenShot();
			return found;
		}
		
		
	}
	public boolean elementNotExists(String locator){		
		boolean found=false;
		try{
			logger.info("Check if element not found with locator:"+locator);
			driver.manage().timeouts().implicitlyWait(10, TimeUnit.SECONDS);
			WebElement element; //= findElementByXpath(locator);
			if(locator.startsWith("//")){
				element = findElementByXpath(locator);
			}else{
				element = findElementByID(locator);
			}
			if (element != null){
				found=element.isDisplayed();
			}
			driver.manage().timeouts().implicitlyWait(120, TimeUnit.SECONDS);
			return found;
		}catch(Exception e){
			driver.manage().timeouts().implicitlyWait(120, TimeUnit.SECONDS);
			return found;
		}
		
		
	}
	/*
	 * function to check is CheckBox checked
	 */
	public boolean elementSelected(String locator){
		logger.info("Check if element selected with locator:"+locator);
		boolean checked=false;
		try{
			waitForElementVisibility(locator);
			WebElement element; //= findElementByXpath(locator);
			if(locator.startsWith("//")){
				element = findElementByXpath(locator);
			}else{
				element = findElementByID(locator);
			}
			if (element != null){
				checked=element.isSelected();
			}
			return checked;
		}catch(Exception e){
			logger.error("Element not found on the page:" + e.getMessage());
			screenShot();
			return checked;
		}
		
		
	}
	public void moveMousetoElement(String locator){
		try{
			waitForElementVisibility(locator);
			WebElement element; //= findElementByXpath(locator);
			if(locator.startsWith("//")){
				element = findElementByXpath(locator);
			}else{
				element = findElementByID(locator);
			}
			Actions act=new Actions(driver);
			act.moveToElement(element);
		}catch(Exception e){
			logger.error("Element not found on the page:" + e.getMessage());
			screenShot();
			throw new MainBrowserException("move Mouse to Ellement failed",e);
			
		}
	}
    public void acceptJSpopup(){
    	Alert alrt=driver.switchTo().alert();
    	alrt.accept();
    }
    public void cancelJSpopup(){
    	Alert alrt=driver.switchTo().alert();
    	alrt.dismiss();
    }
    public boolean isAlertPresent() 
    { 
    	
        try 
        { 
        	Thread.sleep(3000);
            driver.switchTo().alert(); 
            return true; 
        }   
        catch (NoAlertPresentException Ex) 
        { 
            return false; 
        } catch (InterruptedException e) {
			e.printStackTrace();
			return false; 
		}
    } 
	public void takeScreenShot(){
		logger.info("About to take ScreenShot On Failure");
		WebDriver augmentedDriver = new Augmenter().augment(driver);
        String screenshot = ((TakesScreenshot)augmentedDriver).
                            getScreenshotAs(OutputType.BASE64);
        logger.info("data:image/jpeg;base64,"+screenshot);
	}

	public String captureScreen() {
    String path;
    try {
        WebDriver augmentedDriver = new Augmenter().augment(driver);
        File source = ((TakesScreenshot)augmentedDriver).getScreenshotAs(OutputType.FILE);
        path = "./target/screenshots/" + source.getName();
        FileUtils.copyFile(source, new File(path)); 
    }
    catch(IOException e) {
        path = "Failed to capture screenshot: " + e.getMessage();
    }
    return path;
	}
	public RemoteWebDriver getWebDriver(){
		return driver;
	}
	

	
	public List<WebElement> getWebElementListByXPath(String xpath) {
		List<WebElement> list = null;
		try {
			list = driver.findElements(By.xpath(xpath));
		} catch (Exception ex) {
			logger.error("Unable to find Element list By Xpath. Error=" + ex.getMessage());
			screenShot();
			throw new MainBrowserException("Unable to find Element list By given xpath",ex);
		}
		return list;
	}
	
	public void scrollToButtom() {
		JavascriptExecutor jse = (JavascriptExecutor)driver;
		jse.executeScript("window.scrollBy(0,500)", "");
	}
	
	public void scrollToLastTableElement() {
		JavascriptExecutor js = (JavascriptExecutor) driver;
		js.executeScript("window.scrollTo(0, document.body.scrollHeight)");
		moveMousetoElement("__table2-vsb");
		js.executeScript("window.scrollTo(0, document.body.scrollHeight)");
		//EventFiringWebDriver eventFiringWebDriver = new EventFiringWebDriver(driver);
		//eventFiringWebDriver.executeScript("document.querySelector('div[class='sapUiTableVSb']').scrollTop=500");
	}
	
	
	
	
}
