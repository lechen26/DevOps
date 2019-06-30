package com.successfactors.geoip.client;
import com.beust.testng.TestNG;
import com.sap.sfsf.geoip.client.*;

public class ExternalTestNG {
        public static void main(String[] args) {
                        TestNG testng = new TestNG();
                        Class[] classes = new Class[]{NightlyTest.class};
                        testng.setTestClasses(classes);
                        testng.run();
                }
}
