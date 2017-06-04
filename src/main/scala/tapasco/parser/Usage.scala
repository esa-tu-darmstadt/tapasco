package de.tu_darmstadt.cs.esa.tapasco.parser

object Usage {
  def apply(): String = usage

  private final val usage = """
  Tapasco - Usage: tapasco [global options]* [jobs]*

    Global Options:
      --archDir [PATH]          Base directory for architecture descriptions
      --compositionDir [PATH]   Output base directory for Compose jobs
      --coreDir [PATH}          Output base directory for HLS jobs, synthesized cores
      --kernelDir [PATH]        Base directory for kernel descriptions (HLS)
      --platformDir [PATH]      Base directory for platform descriptions
      --logFile [FILE]          Path to output log file
      --configFile [FILE]       Path to Json file with Configuration
      --jobsFile [FILE]         Path to Json file with Jobs array
      --slurm                   Activate SLURM cluster execution (requires sbatch)
      --parallel                Execute all jobs in parallel (careful!)

    Bulk Import Job: bulkimport [options*]
      --csv [FILE]              [FILE] should be in comma-separated values (CSV) format
                                and must contain the following header line and columns:

      "Zip, ID, Description, Architecture, Platform, Avg Runtime (clock cycles)"

    Compose Job: compose [composition] [frequency] [implementation?] [options*] [features*]
      --composition {[FILE] | [DEF]}        Threadpool composition, either in a separate
                                            file, or inline as arguments (see below)
      --designFrequency [NUM]               Target design frequency (PE clock) in MHz
      --implementation [NAME]               Composer implementation (default: Vivado)

      Options:
      --architectures|-a [NAME[, NAME]*]    Filter for Architecture names
      --platforms|-p [NAME[, NAME]*]        Filter for Platform names
      --debugMode [NAME]                    Activate a debug mode

      --features [feature[, feature]*]      Configure optional features.

      Composition Syntax: '[' [NAME] x [NUM] [',' [NAME] x [NUM]]* ']'
      Example:            "[counter x 12, arraysum x 4]"

    Core Statistics Job: corestats [options*]
      --prefix "[PREFIX]"                   File name prefix for CSV output files
      --architectures|-a [NAME[, NAME]*]    Filter for Architecture names
      --platforms|-p [NAME[, NAME]*]        Filter for Platform names

    Design Space Exploration: dse [composition] [dimensions] [batch size] [options*] [features*]
      --composition {[FILE] | [DEF]}        Threadpool composition, either in a separate
                                            file, or inline as arguments (see below)
      --dimensions [area | frequency | alternatives] ["," [area | frequency | alternatives]]*
        area:                               Enable variation of area (number PEs)
        frequency:                          Enable variation of frequency
        alternatives:                       Enable variation of core variants (core w/same ID)
      --batchSize [NUM]                     Number of Compose runs per batch (in parallel)

      Options:
      --basePath [PATH]                     Output base directory for all Compositions etc.
                                            (default: $TAPASCO_HOME/DSE_[TIMESTAMP])
      --heuristic [heuristic]               Select ordering heuristic (default: job throughput):
        throughput                          Optimize job throughput (requires avg. clock cycles)
      --frequency [NUM]                     Initial design frequency (MHz)
      --architectures|-a [NAME[, NAME]*]    Filter for Architecture names
      --platforms|-p [NAME[, NAME]*]        Filter for Platform names
      --debugMode [NAME]                    Activate a debug mode

      --features [feature[, feature]*]      Configure optional features.

      Composition Syntax: '[' [NAME] x [NUM] [',' [NAME] x [NUM]]* ']'
      Example:            "[counter x 12, arraysum x 4]"

    High-Level Synthesis Job: hls [options*]
      --implementation|-i [NAME]            HLS implementation (default: VivadoHLS)
      --kernels|-k [NAME[, NAME]*]          Filter for Kernel names
      --architectures|-a [NAME[, NAME]*]    Filter for Architecture names
      --platforms|-p [NAME[, NAME]*]        Filter for Platform names

    Import Job: import [options*]
      --zip [FILE]                          Path to .zip file containing IP-XACT core
      --id [NUM]                            Kernel ID (> 0) for use in TPC
      --averageClockCycles [NUM]            Avg. clock cycles per execution (optional)
      --description "[TEXT]"                Kernel description text (optional)
      --architectures|-a [NAME[, NAME]*]    Filter for Architecture names
      --platforms|-p [NAME[, NAME]*]        Filter for Platform names
  """
}
