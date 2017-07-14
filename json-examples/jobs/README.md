TaPaSCo Jobs Json Formats
=========================
This directory contains an example for each kind of job in TaPaSCo.
`Jobs.json` gives an example for the syntax of a Jobs file, which
can be directly input via `tapasco --jobsFile <FILE>`.

In the following, each parameter is marked with mandatory or
optional: Optional parameters can simply be omitted in the Json.
The `Job` property is mandatory for all jobs.

BulkImportJob
-------------
  + `CSV` - mandatory

ComposeJob
----------
  + `Composition`             - mandatory
  + `Composition.Description` - optional
  + `Composition.Composition` - mandatory
  + `Design Frequency`        - mandatory
  + `Implementation`          - optional (default: "Vivado")
  + `Architectures`           - optional (default: all)
  + `Platforms`               - optional (default: all)
  + `DebugMode`               - optional

CoreStatisticsJob
-----------------
  + `File Prefix`             - optional
  + `Architectures`           - optional
  + `Platforms`               - optional

DesignSpaceExplorationJob
-------------------------
  + `Initial Composition`     - mandatory
  + `Initial Frequency`       - mandatory if `Dimensions.Frequency` is not `true`
  + `Dimensions`              - mandatory
  + `Dimensions.Frequency`    - mandatory
  + `Dimensions.Utilization`  - mandatory
  + `Dimensions.Alternatives` - mandatory
  + `Heuristic`               - optional (default: "job throughput")
  + `Batch Size`              - mandatory
  + `Output Path`             - optional
  + `Architectures`           - optional
  + `Platforms`               - optional
  + `DebugMode`               - optional

HighLevelSynthesisJob
---------------------
  + `Implementation`          - optional (default: "VivadoHLS")
  + `Architectures`           - optional (default: all)
  + `Platforms`               - optional (default: all)
  + `Kernels`                 - optional (default: all)

ImportJob
---------
  + `Zip`                     - mandatory
  + `Id`                      - mandatory
  + `Description`             - optional
  + `Average Clock Cycles`    - optional (default: 1)
  + `Architectures`           - optional (default: all)
  + `Platforms`               - optional (default: all)
 
