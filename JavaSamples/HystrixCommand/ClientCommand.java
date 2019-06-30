import com.netflix.hystrix.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ClientCommand extends HystrixCommand<GeoIPResult> {

	private IClient client;
	private String arg1;
	private String arg2;
	private ResultFactory resultFactory;


	private static final Logger logger = LoggerFactory.getLogger(ClientCommand.class);


	public ClientCommand(IClient client, String arg1, String arg2, String userIp,ResultFactory resultFactory) {
		super (Setter.withGroupKey (HystrixCommandGroupKey.Factory.asKey ("GeoIPClientHystrix"))
				.andCommandPropertiesDefaults (HystrixCommandProperties.Setter ()
						.withExecutionIsolationStrategy (HystrixCommandProperties.ExecutionIsolationStrategy.SEMAPHORE)
						.withExecutionTimeoutInMilliseconds (GeoIpClientConst.HYSTRIX_CMD_TIMEOUT)
						.withCircuitBreakerRequestVolumeThreshold (client.getConfiguration ().getMinVolume ()) // min amount of traffic to start using the circuit
						.withCircuitBreakerErrorThresholdPercentage(client.getConfiguration ().getErrorThreshold ()) // % of failed attempts to trip the circuit
						.withCircuitBreakerSleepWindowInMilliseconds(client.getConfiguration ().getFailFast ()) // the time we fail fast before switching to Half Open
						.withCircuitBreakerEnabled (true)
						.withFallbackEnabled (true)));
		this.client = client
		this.arg1 = arg1;
		this.arg2 = arg2;
		logger.debug("Hystrix HealthMetrics: [Requests={},Errors={},Perc={}]",getMetrics ().getHealthCounts ().getTotalRequests (),getMetrics ().getHealthCounts ().getErrorCount (),getMetrics ().getHealthCounts ().getErrorPercentage ());
	}

	@Override
	protected Result run() throws ClientException{
		return client.validateUserHystrix (arg1,arg2);
	}

	@Override
	protected Result getFallback() {

		Throwable t = getFailedExecutionException();

		if (t instanceof ClientException) {
			ClientException exception = (ClientException) t;
			return exception.getResult();
		}

		String message = (isResponseShortCircuited ()) ? ClientConst.HYSTERIX_SHORT_CIRCUIT : ((isResponseTimedOut ())
				? ClientConst.HYSTERIX_COMMAND_TIMED_OUT : getFailedExecutionException().getMessage());

		logger.warn("failed execution exception: ", getFailedExecutionException().getCause());

		if (message.equals(ClientConst.HYSTERIX_COMMAND_TIMED_OUT)  || message.equals(ClientConst.HYSTERIX_SHORT_CIRCUIT)) {
			return resultFactory.forBlockedDueToUnreachableService(Utils.computeUnreachableServiceRedirectUrl(Client.getConfiguration()));
		}

		return resultFactory.forClientUnavailable( Client.getConfiguration().getClientDefault(),
				Utils.computeUnreachableServiceRedirectUrl(Client.getConfiguration()), message);

	}


}
