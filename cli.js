#!/usr/bin/env node
var c = require("child_process");

var run = function(cmd, args) {
  if (!args) {
    args = {};
  }
  let errorsAreOkay = !!args.errorsAreOkay;
  delete args.errorsAreOkay;
  // Passes stdout, stderr, stdin to the child process
  args.stdio = [0, 1, 2];
  args.shell = "/bin/bash";
  args.cwd = __dirname;
  try {
    c.execSync(cmd, args);
  } catch (e) {
    if (errorsAreOkay) {
      return;
    }
    console.error("Error executing " + cmd);
    console.error(e);
    process.exit(1);
  }
};

require("yargs")
  .command("start", "destroy your local kube-for-mac installation", argv => {
    run("docker rm -f /docker-kube-for-mac-start", { errorsAreOkay: true });
    run("./hacks/v1.7.3/run ./run-docker-kube-for-mac.sh start");
    run("./hacks/v1.7.3/run ./run-docker-kube-for-mac.sh custom source /etc/hacks-in/hacks.sh DEPLOY-DNS");
    run("./hacks/v1.7.3/run ./run-docker-kube-for-mac.sh custom source /etc/hacks-in/hacks.sh DEPLOY-DASHBOARD");
    run("docker logs -f docker-kube-for-mac-custom", { errorsAreOkay: true });
  })
  .command("destroy", "start a local kube-for-mac installation", argv => {
    run("./hacks/v1.7.3/run ./run-docker-kube-for-mac.sh stop");
  })
  .showHelpOnFail(true)
  .demandCommand()
  .strict().argv;
