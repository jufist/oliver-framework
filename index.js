#!/usr/bin/env node

'use strict';
(async function () {
  require('./common.js');
  var program = require('commander');
  let argv = process.argv;
  var toloadmodule = argv[2];
  argv.splice(2, 1);
  var menus = module_invoke('menu', toloadmodule);
  var menu = require('./includes/menu');
  menu.init(menus);

  var p = program
    .version('0.0.1')
    .allowUnknownOption()
    .option('-c, --cron [cron]', 'Cron executing')
    .option('-u, --ui', 'UI control');
  var menutoarguments = require('./includes/menutoarguments');
  menutoarguments.init(p, menu.menus);
  p.parse(argv);

  // Cron service
  if (program.cron) {
    var cron = require('./includes/cron');
    cron.init(menus);
    return;
  }

  // UI
  if (program.ui) {
    menu.show();

    return;
  }

  var ret = await menutoarguments.handle(p);
  if (ret) {
    return;
  }

  program.help();
})();
