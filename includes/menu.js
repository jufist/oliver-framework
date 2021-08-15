var m = {};

var nodecmd = require('node-cmd');
const prettyPrintJson = require('pretty-print-json');
m.sshEvaluate = function (callback) {
  if (!callback[3] || callback[3] == '127.0.0.1') {
    return callback;
  }

  var args = callback[1];
  args.unshift(callback[3], callback[0]);

  callback[0] = 'ssh';
  callback[1] = args;
  return callback;
};

m.beforeExecute = async function (menuitem) {
  // SSH evaluate
  menuitem['outcallback'] = m.sshEvaluate(menuitem['callback']);

  // Mapping with the callback
  var callback1 = [];
  toReplace = menuitem['toReplace'];
  tokens = GM.config.hosts;
  let shellargs = await getShellArgs(menuitem['outcallback'][1]);
  shellargs.forEach(function (cbelm) {
    try {
      var cbelmx;
      cbelmx = vsprintf(cbelm, toReplace);
      cbelm = cbelmx;
    } catch (e) {}

    try {
      var cbelmx;
      cbelmx = sprintf(cbelm, tokens);
      cbelm = cbelmx;
    } catch (e) {}
    callback1.push(cbelm);
  });
  menuitem['outcallback'][1] = callback1;
};

m.argumentsAsk = async (menuitem) => {
  if (!menuitem['callback_args']) {
    await m.beforeExecute(menuitem);
    return menuitem['outcallback'];
  }
  var fullquestions = menuitem['callback_args'];
  var questions = Object.values(fullquestions);
  var callback = menuitem['callback'];
  var inquirer = require('inquirer');
  var moment = require('moment');
  inquirer.registerPrompt('datetime', require('inquirer-datepicker'));
  var answers = await inquirer.prompt(questions);
  // Results filtering
  var toReplace = [];
  Object.keys(answers).forEach(function (ae) {
    var aeret = answers[ae];
    if (fullquestions[ae]['returnformat']) {
      aeret = moment(aeret).format(fullquestions[ae]['returnformat']);
    }
    toReplace.push(aeret);
  });
  menuitem['toReplace'] = toReplace;

  await m.beforeExecute(menuitem);
  return menuitem['outcallback'];
};
m.useNodeCMD = async (cmd) => {
  let argv = process.argv;
  argv.shift();
  argv.shift();
  argv.shift();
  var cmdc = sprintf(
    cmd,
    extend({ arguments: '"' + argv.join('" "') + '"' }, argv)
  );
  var cmdcd = cmdc
    .split(/\n/)
    .filter((n) => n.trim())
    .join(' && ');
  cmdcd = cmdcd
    .replace(/\\/g, '\\\\')
    .replace(/\$/g, '\\$')
    .replace(/'/g, "\\'")
    .replace(/"/g, '\\"');
  cmdcd = `bash -c "${cmdcd}"`;
  console.error(`${cmdcd}`);
  return await new Promise((resolve, reject) => {
    let data_line = '';
    const processRef = nodecmd.get(cmdcd, function (err, data, stderr) {
      if (err && err.code && err.code === 1) {
        reject({ message: data, err: stderr, status: 400 });
      }
      data = data.replace(/\\n/g, '\n');
      let out = { message: data, err: stderr };
      // If json return, data will be stderr
      try {
        let dataJson = JSON.parse(data);
        out = extend(out, dataJson);
        out.message = out.err;
        out.err = '';
      } catch (e) {
        // console.log(e);
      }
      resolve(out);
    });
    processRef.stdout.on('data', function (data) {
      data_line += data;
      if (data_line[data_line.length - 1] == '\n') {
        console.log(data_line);
      }
    });
  });
};

m.convertToCallbacksWithServiceTypes = (orig) => {
  if (!orig['callback'][5]) {
    return [orig];
  }
  var out = [];
  for (host of GM.config['nodes_' + orig['callback'][5] + 's']) {
    var neworig = extend(true, {}, orig);
    neworig['callback'][3] = host;
    out.push(neworig);
  }
  return out;
};

m.buildCallback = function (menuitem) {
  var callbacks = menuitem['callbacks'] || [menuitem['callback']];
  var promises = [];

  var tmpmn = {};
  var single;
  callbacks.forEach(function (cb) {
    tmpmn = extend(true, {}, menuitem, { callback: cb });
    var tmpmns = m.convertToCallbacksWithServiceTypes(tmpmn);
    for (const _t of tmpmns) {
      single = m.buildACallback(_t);
      promises.push(_t['callbackfinal']);
    }
  });
  menuitem['callbackfinal'] = async () => {
    var pms = [];
    for (const pm of promises) {
      await pm();
    }
  };
  return menuitem['callbackfinal'];
};

var getShellArgs = async function (argument) {
  argument = argument || [];
  if (argument === '$@') {
    let argv = process.argv;
    argv.shift();
    argv.shift();
    argv.shift();
    return argv;
  }
  return argument;
};

m.buildACallback = function (menuitem) {
  var callback = menuitem['callback'];
  var ret = callback;
  var gmodule = menuitem['gmodule'];
  var location = menuitem['callback_location'] || '';

  // Callback location can be overwrite via callback array
  if (callback[4]) {
    location = callback[4];
  }
  menuitem['callback_location'] = `tools/${gmodule}/` + location;
  let disables = GM.config.disables || '';
  if (disables.indexOf(gmodule) !== -1) {
    ret = () => {
      cl('[Info] Module is disabled!');
    };
  } else if (typeof callback == 'object') {
    ret = async () => {
      // Ask for argument if available
      newcallback = await m.argumentsAsk(menuitem);

      // Print Title
      if (newcallback[2]) {
        cl(`[Step] ${newcallback[2]}`);
      }

      // Execute command
      try {
        if (newcallback[6] == 'node-cmd') {
          out = await m.useNodeCMD(
            `>/dev/null cd ${menuitem['callback_location']}; ` + newcallback[0]
          );
          // cl(out.message);
          // console.error(out.err);
          return;
        }

        out = await GM.exec(newcallback[0], newcallback[1], {
          cwd: menuitem['callback_location'],
          env: process.env
        });
        cl(out);
      } catch (e) {
        cl('[Exec] [Error]');
        cl(e);
      }
    };
  } else {
    ret = callback;
  }
  menuitem['callbackfinal'] = ret;
  return ret;
};

m.updateMissingInfo = function (menus) {
  Object.keys(menus).forEach(function (e) {
    var mn = menus[e];
    menus[e] = extend({}, { title: 'Default' }, mn);
    if (mn.children) {
      // Build children
      var childquestions = {};
      Object.keys(mn.children).forEach(function (childe) {
        var childmn = mn.children[childe];
        menus[e].children[childe] = extend({}, { title: 'Default' }, childmn);
      });
    }
  });
  m.menus = menus;
};

/**
 * Recursive prompt example
 * Allows user to choose when to exit prompt
 */
m.init = function (menus) {
  m.updateMissingInfo(menus);
  menus = m.menus;
  var output = [];

  // Convert menu to questions
  var questions = {};
  Object.keys(menus).forEach(function (e) {
    var mn = menus[e];
    if (mn.children) {
      // Build children
      var childquestions = {};
      Object.keys(mn.children).forEach(function (childe) {
        var childmn = mn.children[childe];
        childquestions[childmn['title']] = m.buildCallback(childmn);
      });

      questions[mn['title']] = {
        message: mn['title'],
        choices: childquestions
      };
    } else {
      questions[mn['title']] = m.buildCallback(mn);
    }
  });

  // Inquirer menus
  m.questions = questions;
};

m.show = function () {
  const menu = require('inquirer-menu');
  function createMenu() {
    return {
      message: 'AntBuddy',
      choices: m.questions
    };
  }
  menu(createMenu)
    .then(function () {
      console.log('bye');
    })
    .catch(function (err) {
      console.log(err.stack);
    });
};

module.exports = m;
