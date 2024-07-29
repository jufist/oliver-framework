GM = global.GM || {};

var fs = require('fs');
var path = require('path');
var util = require('util');
var appRoot = require('path').dirname(require('path').dirname(__dirname));
var config;
let LOCALDIR = global.LOCALDIR || '';
let NAMESPACE = global.NAMESPACE || '';
let loadconfig = (localconfigdir, namespace) => {
  namespace = namespace || '';
  let localconfigvar = {};
  let localconfig = localconfigdir + '/.control.js';
  let localconfig2 = localconfigdir + '/.control.' + namespace + '.js';
  try {
    if (fs.existsSync(localconfig2)) {
      localconfigvar = require(localconfig2);
    } else {
      if (fs.existsSync(localconfig)) {
        localconfigvar = require(localconfig);
      } else {
        return {};
      }
    }
  } catch (err) {
    // Nothing
    console.error(err);
    return {};
  }
  return { ...{ localconfig: localconfigdir }, ...localconfigvar };
};

try {
  let namespace = NAMESPACE || '';
  let grouppath = `${appRoot}/groups/${namespace}/config.js`;
  if (fs.existsSync(grouppath)) {
    config = require(grouppath);
  } else {
    if (fs.existsSync(appRoot + '/config.js')) {
      config = require(appRoot + '/config.js');
    } else {
      config = {};
    }
  }

  let localconfig = LOCALDIR != '' ? LOCALDIR : '';
  if (localconfig != '') {
    let localconfigvar = loadconfig(localconfig, namespace);
    config = { ...config, ...localconfigvar };
    if (!Object.keys(localconfigvar).length) {
      localconfigvar = loadconfig(path.dirname(localconfig), namespace);
      config = { ...config, ...localconfigvar };
    }
  }
} catch (e) {
  config = {};
  console.warn(e);
}
config = config || {};

config.basedir = appRoot + '';
let _loadedjQuery = false;
let loadjQuery = () => {
  if (_loadedjQuery) return;
  _loadedjQuery = true;

  let jsdom = require('jsdom');
  const { JSDOM } = jsdom;
  const { window } = new JSDOM();
  const { document } = new JSDOM('').window;
  // global.document = document;
  global.$ = require('jquery')(window);
};

GM.evalvar = (item, y) => {
  loadjQuery();
  let PHASE = { ...item };
  let debug = false;
  // debug = item.id=='maincontent_variable';
  Object.keys(PHASE).forEach((key) => {
    let iitem = item[key];
    if ($.isPlainObject(iitem)) {
      PHASE[key + 'b64'] = encode.encode(JSON.stringify(iitem), 'base64');
      PHASE[key + 'param'] = $.param(iitem);
    }
  });
  debug && console.error(['Orig item', item]);
  let z = JSON.stringify(y).replace(/\\n/g, 'cRnN');
  // backslash issue
  z = z.replace(/\\/g, '\\\\');
  z = `z =\`${z}\``;
  debug && console.error(['Stringify before parsing token', z, y]);
  eval(z);
  z = z.replace(/\n/g, 'cRnN');
  debug && console.error(['After parsing token', z]);
  z = `z = ${z}`;
  z = z.replace(/cRnN/g, '" + \'\\n\' + "');
  debug && console.error(['Before convert object string to object', z]);
  eval(z);
  debug && console.error(['After convert', z]);
  // convert cRnN
  // Object.keys(z).forEach((k) => {
  // z[k] = $.type(z[k]) !== 'string' ? z[k] : z[k].replace(/cRnN/g, "\n");
  //});
  // debug && console.log(['DEBUG4', z]);
  return z;
};
global.sprintf = require('sprintf-js').sprintf;
global.vsprintf = require('sprintf-js').vsprintf;

Object.defineProperty(global, '__stack', {
  get: function () {
    var orig = Error.prepareStackTrace;
    Error.prepareStackTrace = function (_, stack) {
      return stack;
    };
    var err = new Error();
    Error.captureStackTrace(err, arguments.callee);
    var stack = err.stack;
    Error.prepareStackTrace = orig;
    return stack;
  }
});

Object.defineProperty(global, '__line', {
  get: function () {
    return __stack[1].getLineNumber();
  }
});

Object.defineProperty(global, '__function', {
  get: function () {
    return __stack[1].getFunctionName();
  }
});

global._function = function () {
  var re = /function (.*?)\(/;
  var s = _function.caller.toString();
  console.log(s);
  var m = re.exec(s);
  return m[1];
};

global.extend = require('extend');
global.nodeproxy = require('nodeproxy');
global.promiseForeach = require('promise-foreach');
String.prototype.replaceAll = function (search, replacement) {
  var target = this;
  return target.split(search).join(replacement);
};

GM.config = config;
if (config.logFile) {
  GM.log_file = fs.createWriteStream(config.logFile, { flags: 'w' });
}

global.cl = require('debug')('oliver-framework');

// Common
global.clexec = function (cmd, withcmd, outcallback, rejcallback, args, options) {
  options = options || {};
  args = args || [];
  outcallback =
    outcallback ||
    function (out, resolve) {
      resolve(out);
    };
  rejcallback =
    rejcallback ||
    function (out, resolve) {
      resolve(out);
    };
  return new Promise(function (resolve, reject) {
    const { exec } = require('child_process');
    withcmd = withcmd || 0;

    if (withcmd) {
      cl(`[Exec] ${cmd} ` + args.join(' '));
    } else {
      cl(`[Info] ${cmd}`);
    }
    if (withcmd) {
      var childProcess = require('child_process');
      // childProcess.spawn = require('cross-spawn'); BUGGY
      var spawn = childProcess.spawn;
      var ls = spawn(cmd, args, options);
      var stdout = [];
      var stderr = [];
      ls.stdout.on('data', (data) => {
        cl(`[Debug] [Cmd] ${data}`);
        stdout.push(data);
      });
      ls.stderr.on('data', (data) => {
        cl(`[Debug] [Cmd] [Error] ${data}`);
        stderr.push(data);
      });
      ls.on('error', (err) => {
        cl(err);
        // rejcallback(['Failed to start subprocess.', err, stderr], function() {reject()});
      });
      ls.on('close', (code) => {
        stdout = stdout.join('\n');
        stderr = stderr.join('\n');
        // Error
        if (code !== 0) {
          rejcallback(stderr, function () {
            reject(stdout);
          });
          return;
        }
        outcallback(stdout, function () {
          resolve(stdout);
        });
      });
      /*var eprocess = exec(cmd, {maxBuffer: 1024 * 20000, encoding: "UTF-8"}, (err, stdout, stderr) => {
        cl(`[Exec finished] ${cmd}`);
        if (err) {
          rejcallback(err);
          reject(err);
          return;
        }
        outcallback(stdout);
        resolve(stdout);
      });
      if (config.debug) {
        eprocess.stdout.pipe(process.stdout);
      }*/
    } else {
      outcallback('', function () {
        resolve('');
      });
    }
  });
};

GM.exec = function (cmd, args, options, res = false, rej = false) {
  return clexec(
    cmd,
    1,
    res ||
      function (out, resolve) {
        resolve(out);
      },
    rej ||
      function (out, resolve) {
        resolve(out);
      },
    args,
    options
  );
};

// clexecthen func
const PromiseQueue = require('easy-promise-queue').default;
var _promises = new PromiseQueue({ concurrency: 1 });
global.clexecthen = function (cmd, withcmd, args, options, outcallback, rejcallback) {
  options = options || {};
  args = args || {};
  withcmd = withcmd || 0;
  outcallback =
    outcallback ||
    function (out, resolve) {
      resolve(out);
    };
  rejcallback =
    rejcallback ||
    function (out, resolve) {
      resolve(out);
    };
  if (withcmd) {
    cl(`[Queue] ${cmd}`);
  }
  _promises.add(() => {
    return clexec(cmd, withcmd, outcallback, rejcallback, args, options);
  });
};

GM.mysqlinit = function (done) {
  if (this._mysqlinited) {
    done.call(this);
    return;
  }
  var t = this;
  this._mysqlinited = 1;
  var mysql = require('mysql');

  var con = mysql.createConnection({
    host: 'localhost',
    user: config.localrepo.user,
    password: config.localrepo.pw,
    database: config.localrepo.db
  });
  this.mysqlcon = con;
  con.connect(function (err) {
    if (err) throw err;
    done.call(t);
  });
};
GM.shutdown = function () {
  cl('[Phase] Byebye!');
  if (this.mysqlcon) {
    this.mysqlcon.end();
  }
  process.exit(22);
};

GM.nativemysql = function (sql, done) {
  var t = this;
  this.mysqlinit(function () {
    this.mysqlcon.query(sql, function (err, result) {
      if (err) throw err;
      done.call(t, result);
    });
  });
};

GM.mysql = function (sql, done) {
  sql = sql.replaceAll('"', '\\"');
  // TODO: Replace keys to \`keys\`
  clexecthen(
    `ssh repo-prod "mysql -u ${config.repo.user} -p${config.repo.pw} ${config.repo.db} -e '${sql}'"`,
    1,
    [],
    {},
    (out, resolve) => {
      done();
      resolve();
    }
  );
};

GM.mysqljsonshell = function (sql, done) {
  var t = this;
  this.mysql(sql, function (out) {
    out = out.split('\n');
    for (i in out) {
      out[i] = out[i].split('\t');
    }
    if (out[0]) {
      col = out[0];
      out.pop();
      out.shift();
    }
    myret = [];
    for (i in out) {
      rec = {};
      for (j in col) {
        rec[col[j]] = out[i][j];
      }
      myret.push(rec);
    }

    done.call(t, myret);
  });
};

GM.mysqljson = function (sql, done) {
  return GM.nativemysql(sql, done);
};

global.module_invoke = function (callback, parentdir = 'modulefile') {
  return module_invoke_all(callback, '../', parentdir);
};

/**
 * Invokes a hook in all enabled modules that implement it.
 * Example: Check antbuddy code
 */
global.module_invoke_all = function (callback, basedir = 'modules', filterdir = false) {
  var callarguments = Array.prototype.slice.call(arguments);
  callarguments.shift();
  callarguments.shift();
  var normalizedPath = require('path').join(config.basedir, basedir);
  var path = require('path');
  var fs = require('fs');
  var finalresults = {};
  fs.readdirSync(normalizedPath).forEach(function (file) {
    if (!fs.statSync(normalizedPath + '/' + file).isDirectory()) {
      return;
    }
    if (filterdir && file != filterdir) {
      return;
    }
    var modulename = path.basename(file);
    if (!fs.existsSync(path.resolve(basedir + '/' + file + '/' + modulename + '.js'))) {
      return;
    }
    var lib = require(path.resolve(basedir + '/' + file + '/' + modulename + '.js'));
    var ret;
    if (typeof callback == 'string') {
      if (lib[callback]) {
        ret = lib[callback].apply(lib, callarguments);
      } else {
        ret = {};
      }
    } else {
      ret = nodeproxy(callback, lib).apply(lib, [lib].concat(callarguments));
    }

    var addGmodule = function (tmpVal) {
      Object.keys(tmpVal).forEach(function (rete) {
        tmpVal[rete].gmodule = modulename;
        if (tmpVal[rete]['children']) {
          addGmodule(tmpVal[rete]['children']);
        }
      });
    };
    addGmodule(ret);

    extend(finalresults, ret);
  });
  return finalresults;
};

GM.argv = require('minimist')(process.argv.slice(2));

/* TODO: Move to repository:
 * Export variable to bash
 */
GM.exportbash = function (v) {
  Object.keys(v).forEach((i) => {
    if (typeof v[i] != 'object') {
      console.log(`export ${i}="${v[i]}"`);
    } else {
      // Export object
      const items = [];
      Object.keys(v[i]).forEach((ii) => {
        if (typeof v[i][ii] != 'object') {
          // Allow \n to render normally in bash
          const s = JSON.stringify(`${v[i][ii]}`).replaceAll('\\n', '\n').replaceAll('$', '\\$');
          items.push(`  [${ii}]=${s}`);
        }
      });
      console.log(`declare -A ${i}; export ${i}=(` + items.join(' ') + `)`);
    }
  });
};

global.GM = GM;
module.exports = {};
