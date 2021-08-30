# Introduction 
Within this blog post you will be setting up a YAML pipeline that will perform maintenance on your SQL Azure databases.
Creating and executing a stored procedure running on a scheduled base.

Benefits of using Azure DevOps pipeline as your scheduler is that it is free, 
is has no external dependencies, it does not use 'run-as-account' that might expire and it is easy to setup/maintain.
Since SQL Azure does not support SQL agent and you do want to maintain the indexes on your databases on a periodic base,
this is the solution I came up with.

It makes use of the stored procedure created by Yochanan Rachamim.
https://github.com/yochananrachamim/AzureSQL/blob/master/AzureSQLMaintenance.txt, all credits for him! 
    
# Prerequisites

    - Azure subscription
    - Azure DevOps
    - AZ Cli on your build agent

# Getting Started

1.	Clone the git repository and use it within your project [link](https://github.com/bstoop-github/sqldb-maintenance-pipeline).
2.	Create a new pipeline in your ADO project and point it to 'pipelines\sqldb-maintenance-pipeline.yml'.
3.	Create environments in your ADO project ( in this pipeline 'TST', 'ACC' and 'PRD' are being used).
4.	Ensure you have a service connection setup from ADO to your Azure subscription [link](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml).
5.  Fill the variable files in /variables/*.yml with the values that correspond with the environment and resources you use.
6.  Run the pipeline manually to validate functionallity.

# Important
Note that the default run of this pipelines is scheduled in this file: 'pipelines\sqldb-maintenance-pipeline.yml'.
To be found in the following section:

    schedules:
    - cron: "0 12 * * 0"
    displayName: Weekly Sunday build
    branches:
        include:
        - main
    always: true

Resuling the pipeline to run on a weekly base, each sunday.

___

Enjoy this solution and contact me whenever you have any feedback.
