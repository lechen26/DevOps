
mode = (disable == "true")
[
  [jobname: "job1"],
  [jobname: "job2"]
].each { Map config ->
  pipelineJob(config.jobname) {
    using(config.jobname)
    disabled(mode)
  }
}
