package de.tu_darmstadt.cs.esa.threadpoolcomposer.jobs.executors
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.base._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.Logging
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.task._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.jobs._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.activity.hls.HighLevelSynthesizer
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.activity.hls.HighLevelSynthesizer._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.activity.hls.HighLevelSynthesizer.Implementation._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.filemgmt.FileAssetManager
import  java.util.concurrent.Semaphore

protected object HighLevelSynthesis extends Executor[HighLevelSynthesisJob] {
  private implicit final val logger = Logging.logger(getClass)

  def execute(job: HighLevelSynthesisJob)(implicit cfg: Configuration, tsk: Tasks): Boolean = {
    val signal = new Semaphore(0)
    val runs: Seq[(Kernel, Target)] = for {
      a <- job.architectures.toSeq.sortBy(_.name)
      p <- job.platforms.toSeq.sortBy(_.name)
      k <- job.kernels.toSeq.sortBy(_.name)
      t = Target(a, p)
    } yield (k, t)

    val tasks = for {
      (k, t) <- runs
    } yield new HighLevelSynthesisTask(k, t, cfg, VivadoHLS, _ => signal.release())

    tasks foreach { tsk.apply _ }

    0 until tasks.length foreach { i =>
      signal.acquire()
      logger.debug("HLS task #{} collected", i)
    }

    logger.info("all HLS tasks have finished.")

    val results: Seq[((Kernel, Target), Option[HighLevelSynthesizer.Result])] =
      (runs zip (tasks map (_.synthesisResult))) filter {
        case (_, Some(Success(_, _))) => true
        case _                        => false
      }

    logger.trace("results: {}", results)

    val importTasks = results flatMap {
      case ((k, t), Some(Success(_, zip))) => {
        val avgCC = FileAssetManager.reports.cosimReport(k.name, t) map (_.latency.avg)
        if (avgCC.isEmpty && k.testbenchFiles.length > 0) {
          logger.warn("executed HLS with co-sim for {}, but no co-simulation report was found", k)
        }
        Some(new ImportTask(zip, t, k.id, avgCC, _ => signal.release())(cfg))
      }
      case _ => None
    }

    importTasks foreach { tsk.apply _ }

    0 until importTasks.length foreach { i =>
      signal.acquire()
      logger.debug("Import task #{} collected", i)
    }

    // success, if all tasks were successful
    ((tasks ++ importTasks) map (_.result) fold false) (_ || _)
  }
}
