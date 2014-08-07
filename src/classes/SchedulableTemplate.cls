/**
 * @author      Josep Vall-llobera <valnavjo_at_gmail.com>
 * @version     1.0.0
 * @since       19/08/2012
 */
global abstract class SchedulableTemplate implements Schedulable {
	
	/**CONSTANTS*/
	private static final Integer DEFAULT_PERIODICITY = 1;
	
	/**ATTRIBUTES*/
	private Boolean autoSchedule = false;
	private Integer periodicity;//Minutes
	private Boolean deactivate = false, terminate =  false;
	private Boolean sendErrors;
	private String emailAddress;

	private Boolean fromBatchable = false;
	private Boolean parallelExecutions;

	/**SCHEDULABLE METHODS*/
	global void execute(SchedulableContext sc) {
		System.debug('Executing "SchedulableTemplate.execute()".');
		System.debug('Parameters --> sc: ' + sc);

		//Initialize Schedulable variables
		this.schInit();

		//If a Batch job is gonna be executed, we must check that we
		//are not going to break the salesforce limit
		if (this.fromBatchable && this.getExistingJobsCount() > 4) {
			//If there already are the maximum number of active jobs
			//we abort the current one and re-schedule it
			System.abortJob(sc.getTriggerId());
			this.autoSchedulable(this);
			return;
		}
		
		//Abort the job and exit method
		else if (this.terminate) {
			System.abortJob(sc.getTriggerId());
			return;
		
		//If the job must be re-scheduled, we must abort it before
		} else if (this.autoSchedule) {
			System.abortJob(sc.getTriggerId());
		}
		
		//Execute the job
		try {
			//If the job is deactivated, we don't have to execute this method
			if (!this.deactivate) this.schExecute(sc);
		} catch (Exception e) {
			System.debug('SchedulableTemplate Exception --> ' + e);
			if (this.sendErrors) this.sendEmail(e.getMessage());
		} finally {
			//Scheduling itself
			if (this.autoSchedule) {
				
				//Batchable methods won't execute so we need to autoschedule the job here
				if (this.fromBatchable && this.deactivate) {
					this.autoSchedulable(this);
				
				//We don't have to wait until the Batch process is finished to re-schedule the job
				} else if (this.fromBatchable && this.parallelExecutions) {
					this.autoSchedulable(this);

				//Not from Batch? Go ahead!
				} else if (!this.fromBatchable) {
					this.autoSchedulable(this);
				}
			}
		}
	}
	
	/**ABSTRACT METHODS*/
	global abstract void schInit();
	global abstract void schExecute(SchedulableContext sc);
	
	/**PROTECTED METHODS*/
	//-- GETTERS
	protected Boolean getAutoSchedule() { return this.autoSchedule; }
	protected Boolean getSendErrors() {return this.sendErrors; }
	
	protected Boolean getParallelExecutions() {return this.parallelExecutions; }
	
	//-- SETTERS
	protected SchedulableTemplate setAutoSchedule(final Boolean autoSchedule) { this.autoSchedule = autoSchedule; return this; }
	protected SchedulableTemplate setPeriodicity(final Integer periodicity) { this.periodicity = this.checkPeriodicity(periodicity); return this; }
	protected SchedulableTemplate setDeactivate(final Boolean deactivate) { this.deactivate = deactivate; return this; }
	protected SchedulableTemplate setTerminate(final Boolean terminate) { this.terminate = terminate; return this; }
	protected SchedulableTemplate setSendErrors(final Boolean sendErrors) { this.sendErrors = sendErrors; return this; }
	protected SchedulableTemplate setEmailAddress(final String emailAddress) { this.emailAddress = emailAddress; return this; }
	
	protected SchedulableTemplate setFromBatchable(final Boolean fromBatchable) { this.fromBatchable = fromBatchable; return this; }
	protected SchedulableTemplate setParallelExecutions(final Boolean parallelExecutions) { this.parallelExecutions = parallelExecutions; return this; }

	/**
	 * Schedule the job. It´s important to notice that this method is called after
	 * aborting the current job. Otherwise it would crash.
	 */
	protected void autoSchedulable(final Schedulable sch) {
		final String minuteString = System.now().addMinutes(this.periodicity).minute().format();
		final String cron = '05 '+ minuteString + ' * * * ?';
		
		System.schedule(this.getclassName(), cron, sch);
	}
	
	/**
	 * Send an email to the email address especified in "emailAddress"
	 * class attribute.
	 */
	protected void sendEmail(final String message) {
		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
		mail.setReplyTo('noreply@noreply.com');
		mail.setSenderDisplayName('No-Reply');
		mail.setSaveAsActivity(false);
		mail.setUseSignature(false);
		
		mail.setToAddresses(new String[] { this.emailAddress });
		mail.setSubject(this.getclassName() + ' has thrown an Exception.');
		mail.setHtmlBody('<h1>' + this.getclassName() + '</h1>' +
						 '<p>This is the exception\'s error message:</p>' +
						 message);

		Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
	}

	/**PRIVATE METHODS*/
	/**
	 * Returns the number of current queued or processing jobs.
	 */
	private Integer getExistingJobsCount() {
		final Integer asyncAoexJobsCount = [select count()
											from AsyncApexJob
											where Status IN ('Queued', 'Processing') AND
												  JobType <> 'BatchApexWorker'];

		return asyncAoexJobsCount;
	}

	/**
	 * Returns the name of the class that is executing in that moment.
	 */
	private String getClassName() {
		return this.toString().substring(0, this.toString().indexOf(':'));
	}
	
	/**
	 * Checks the periodicity value. If it is less than 0 or greate than 59,
	 * it returns the default periodicity (1 minute).
	 */
	private Integer checkPeriodicity(final Integer periodicity) {
		return (periodicity == null || periodicity < 0 || periodicity > 59) ? DEFAULT_PERIODICITY :
																			  periodicity;
	}
}