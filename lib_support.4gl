#+ Check for a new deployment.
#+
#+ The user is informed if there is a newer version of the application.
#+
#+ @return     None
#+
PUBLIC FUNCTION support_deployment()
   TYPE this_t
      RECORD
           dir STRING
         , foundMe BOOLEAN
         , handle INTEGER
         , deployment STRING
         , newDeployment STRING
      END RECORD

   DEFINE
      this this_t
      , dir STRING
      , filter STRING
      , info STRING
      , title STRING
      , idx INTEGER
      , prop property_t
      , max_ignore_count INTEGER

   LET this.dir = os.Path.baseName(base.APPLICATION.getProgramDir())
   IF this.dir == DEPLOYMENT_DEV_PREFIX THEN
      LET this.dir = "master-20180607-144500"
   END IF
   LET this.deployment = this.dir.subString(1, this.dir.getLength() - 2)

   # Either "master-" or "beta-"
   IF this.dir.subString(1,DEPLOYMENT_BETA_PREFIX.getLength()) == DEPLOYMENT_BETA_PREFIX
   THEN
      LET idx = DEPLOYMENT_BETA_PREFIX + 1
   ELSE
      LET idx = DEPLOYMENT_LIVE_PREFIX.getLength() + 1
   END IF
   LET filter = this.dir.subString(1, idx)
   LET dir = ".."

   # Filter for directories only.
   CALL os.Path.dirFMask(GENERO_DIRFMASK_INCLUDE_DIRECTORIES)
   CALL os.Path.dirSort("name", -1)
   LET this.handle = os.Path.dirOpen(dir)
   IF this.handle == 0 THEN
      WRITELOG(SFMT("Failed to open directory %1", dir))
      RETURN
   END IF

   WHILE dir IS NOT NULL
      LET dir = os.Path.dirNext(this.handle)
      # Exclude itself
      IF dir == this.dir THEN
         LET this.foundMe = TRUE
         CONTINUE WHILE
      END IF
      IF dir.subString(1, filter.getLength()) == filter
      THEN
         LET this.newDeployment = dir.subString(1, dir.getLength() - 2)
         EXIT WHILE
      END IF
   END WHILE

   # Prepare for ignore counting.
   LET prop.key01 = fgl_getenv("LOGNAME")

   IF this.newDeployment.getLength() != 0
   AND NOT this.foundMe
   THEN

      # Have previous warnings been ignored too many times?
      LET IGNORE_DEPLOYMENT_WARNING_EXPIRED = properties_get_value_with_key_bool(prop.key01, "IGNORE_DEPLOYMENT_WARNING_EXPIRED", FALSE)
      IF IGNORE_DEPLOYMENT_WARNING_EXPIRED 
      THEN
         WRITELOG("Deployment warnings ignored too many times, the program is not authorised to run.")
         IF FGLGUI THEN
            LET info = SFMT(LSTR("deployment.ignore.expired"), this.newDeployment, this.deployment)
            LET title = LSTR("deployment.new.title")
            CALL support_window(title, info, "stop")
         END IF
         # Don't allow the program to run.
         SUPPORT_EXIT_PROGRAM_WITH_CLEANUP(1)
      END IF

      # Setup the maximum allowed value of the number of times a user can ignore the deployment warning.
      # The user can be given a non-default start count if they are a repeat offender.
      # The value is added manualy to the database table and is constrained between 1 and the default max value.
      LET max_ignore_count = properties_get_value_with_key_int(prop.key01, "IGNORE_DEPLOYMENT_WARNING_MAX", DEPLOYMENT_DEFAULT_IGNORE_COUNT)
      IF max_ignore_count < 1 
      THEN
         LET max_ignore_count = 1
         CALL properties_set_value_with_key(prop.key01, "INT", "IGNORE_DEPLOYMENT_WARNING_MAX", max_ignore_count)
      END IF
      IF max_ignore_count > DEPLOYMENT_DEFAULT_IGNORE_COUNT
      THEN 
         LET max_ignore_count = DEPLOYMENT_DEFAULT_IGNORE_COUNT
         CALL properties_set_value_with_key(prop.key01, "INT", "IGNORE_DEPLOYMENT_WARNING_MAX", max_ignore_count)
      END IF

      LET IGNORE_DEPLOYMENT_WARNING_COUNT = properties_get_value_with_key_int(prop.key01, "IGNORE_DEPLOYMENT_WARNING_COUNT", max_ignore_count)
      CASE
         WHEN
         NOT IGNORE_DEPLOYMENT_WARNING_EXPIRED
         AND IGNORE_DEPLOYMENT_WARNING_COUNT == 0
            # Initialise warning countdown.
            CALL properties_set_value_with_key(prop.key01, "INT", "IGNORE_DEPLOYMENT_WARNING_COUNT", DEPLOYMENT_DEFAULT_IGNORE_COUNT)

         WHEN
         IGNORE_DEPLOYMENT_WARNING_COUNT > 0
            LET IGNORE_DEPLOYMENT_WARNING_COUNT = IGNORE_DEPLOYMENT_WARNING_COUNT - 1
            CALL properties_set_value_with_key(prop.key01, "INT", "IGNORE_DEPLOYMENT_WARNING_COUNT", IGNORE_DEPLOYMENT_WARNING_COUNT)
            IF IGNORE_DEPLOYMENT_WARNING_COUNT == 0
            THEN
               LET IGNORE_DEPLOYMENT_WARNING_EXPIRED = TRUE
               CALL properties_set_value_with_key(prop.key01, "BOOL", "IGNORE_DEPLOYMENT_WARNING_EXPIRED", TRUE)
               CALL properties_delete_value_with_key(prop.key01, "IGNORE_DEPLOYMENT_WARNING_COUNT")
            END IF

      END CASE
      WRITELOG(SFMT("New deployment available: %1", this.newDeployment))
      IF FGLGUI THEN
         LET info = SFMT(LSTR("deployment.newer"), this.newDeployment, this.deployment, IGNORE_DEPLOYMENT_WARNING_COUNT)
         LET title = LSTR("deployment.new.title")
         CALL support_window(title, info, "information")
      END IF
   ELSE
      # No new version so clear up countdown.
      CALL properties_delete_value_with_key(prop.key01, "IGNORE_DEPLOYMENT_WARNING_COUNT")
      CALL properties_delete_value_with_key(prop.key01, "IGNORE_DEPLOYMENT_WARNING_EXPIRED")
   END IF

END FUNCTION
