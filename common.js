GM = global.GM || {};

var fs = require('fs');
var path = require('path');
var util = require('util');
var appRoot = require('path').dirname(require('path').dirname(__dirname));
var config;
let LOCALDIR=global.LOCALDIR || "";
let loadconfig = (localconfig) => {
    let localconfigvar = {};
    try {
        if (fs.existsSync(localconfig)) {
            localconfigvar = require(localconfig);
        }
        else {
            return {};
        }
    } catch(err) {
        // Nothing
        console.error(err);
        return {};
    }
    return {...{localconfig: path.dirname(localconfig)}, ...localconfigvar};
}

try {
    config = require(appRoot + '/config.js');
    let localconfig = LOCALDIR!="" ? LOCALDIR + "/.control.js" : "";
    if (localconfig!='') {
        let localconfigvar = loadconfig(localconfig);
        config = {...config, ...localconfigvar};
        if (!Object.keys(localconfigvar).length) {
          localconfigvar = loadconfig(path.dirname(LOCALDIR) + "/.control.js");
          config = {...config, ...localconfigvar};
        }
    }
}
catch (e) {
    config = {};
    console.error(e);
}
config = config || {};

config.basedir = appRoot + '';
global.sprintf = require('sprintf-js').sprintf;
global.vsprintf = require('sprintf-js').vsprintf;

Object.defineProperty(global, '__stack', {
get: function() {
        var orig = Error.prepareStackTrace;
        Error.prepareStackTrace = function(_, stack) {
            return stack;
        };
        var err = new Error;
        Error.captureStackTrace(err, arguments.callee);
        var stack = err.stack;
        Error.prepareStackTrace = orig;
        return stack;
    }
});

Object.defineProperty(global, '__line', {
get: function() {
        return __stack[1].getLineNumber();
    }
});

Object.defineProperty(global, '__function', {
get: function() {
        return __stack[1].getFunctionName();
    }
});

global._function = function() {
    var re = /function (.*?)\(/
    var s = _function.caller.toString();
    console.log(s);
    var m = re.exec( s )
    return m[1];
}

global.extend = require('extend');
global.nodeproxy = require('nodeproxy');
global.promiseForeach = require('promise-foreach')
String.prototype.replaceAll = function(search, replacement) {
    var target = this;
    return target.split(search).join(replacement);
};

GM.config = config;
if (config.logFile) {
  GM.log_file = fs.createWriteStream(config.logFile, {flags : 'w'});
}
global.cl = function(e) {
  if (!config.debug && (e && e.indexOf && (e.indexOf("[Exec") !== -1 || e.indexOf("[Debug") !== -1))) {
    return;
  }
  var moment = require('moment');
  /*
  ** format time log Ex. [Thu Feb 28 2019 +07:00 14:24:51.757]
  */
  var wrapped = moment(new Date()).format('ddd MMM DD YYYY Z HH:mm:ss.SSS');
  var args = arguments;
  wrapped = `[${wrapped}]`;

  /*if (config.debug) {
    var callerFunction = cl.caller.name;
    wrapped = `${wrapped} [${callerFunction}]`;
  }*/

  var type = Function.prototype.call.bind( Object.prototype.toString );
  if (args.length > 1 || Array.isArray(args[0]) || type( args[0] ) === '[object Object]')   {
    if (GM.log_file) {
      GM.log_file.write(util.format(wrapped) + '\n');
      GM.log_file.write(util.format(args) + '\n');
    }
    console.log(wrapped);
    console.log.apply(this, args);
  }
  else {
    args[0] = wrapped + ' ' + args[0];
    if (GM.log_file) {
      GM.log_file.write(util.format(args) + '\n');
    }
    console.log.apply(this, args);
  }

};

// Common
global.clexec = function(cmd, withcmd, outcallback, rejcallback, args, options) {
  options = options || {};
  args = args || [];
  outcallback = outcallback || function(out, resolve) {resolve(out);};
  rejcallback = rejcallback || function(out, resolve) {resolve(out);};
  return new Promise(function(resolve, reject) {
    const { exec } = require('child_process');
    withcmd = withcmd || 0;

    if (withcmd) {
      cl(`[Exec] ${cmd} ` + args.join(" "));
    }
    else {
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
        stdout = stdout.join("\n");
        stderr = stderr.join("\n");
        // Error
        if (code !== 0) {
          rejcallback(stderr, function() {reject(stdout)});
          return;
        }
        outcallback(stdout, function() {resolve(stdout)});
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
    }
    else {
     outcallback('', function() {resolve('')});
    }
  });
};

GM.exec = function(cmd, args, options) {
  return clexec(cmd, 1, function(out, resolve) {resolve(out);}, function(out, resolve) {resolve(out);}, args, options);
}

// clexecthen func
const PromiseQueue = require("easy-promise-queue").default;
var _promises = new PromiseQueue({concurrency: 1});
global.clexecthen = function(cmd, withcmd, args, options, outcallback, rejcallback) {
  options = options || {};
  args = args || {};
  withcmd = withcmd || 0;
  outcallback = outcallback || function(out, resolve) {resolve(out);};
  rejcallback = rejcallback || function(out, resolve) {resolve(out);};
  if (withcmd) {
    cl(`[Queue] ${cmd}`);
  }
  _promises.add(() => {
    return clexec(cmd, withcmd, outcallback, rejcallback, args, options);
  });
}

GM.mysqlinit = function(done) {
  if (this._mysqlinited) {
    done.call(this);
    return;
  }
  var t = this;
  this._mysqlinited = 1;
  var mysql = require('mysql');

  var con = mysql.createConnection({
    host: "localhost",
    user: config.localrepo.user,
    password: config.localrepo.pw,
    database : config.localrepo.db
  });
  this.mysqlcon = con;
  con.connect(function(err) {
    if (err) throw err;
    done.call(t);
  });
}
GM.shutdown = function() {
  cl("[Phase] Byebye!");
  if (this.mysqlcon) {
    this.mysqlcon.end();
  }
  process.exit(22);
}

GM.nativemysql = function(sql, done) {
  var t = this;
  this.mysqlinit(function() {
    this.mysqlcon.query(sql, function (err, result) {
      if (err) throw err;
      done.call(t, result);
    });
  });
}

GM.mysql = function(sql, done) {
  sql = sql.replaceAll('"', '\\"');
  // TODO: Replace keys to \`keys\`
  clexecthen(`ssh repo-prod "mysql -u ${config.repo.user} -p${config.repo.pw} ${config.repo.db} -e '${sql}'"`, 1, [], {}, (out, resolve) => {done(); resolve();} );
}

GM.mysqljsonshell = function(sql, done) {
  var t = this;
  this.mysql(sql, function(out) {
    out = out.split("\n");
    for (i in out) {
      out[i] = out[i].split("\t");
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
}

GM.mysqljson = function(sql, done) {
  return GM.nativemysql(sql, done);
}


global.module_invoke = function(callback, parentdir = 'modulefile') {
  return module_invoke_all(callback, "../", parentdir);
}

/**
 * Invokes a hook in all enabled modules that implement it.
 * Example: Check antbuddy code
 */
global.module_invoke_all = function(callback, basedir = 'modules', filterdir = false) {
  var callarguments = Array.prototype.slice.call(arguments);
  callarguments.shift();
  callarguments.shift();
  var normalizedPath = require("path").join(config.basedir, basedir);
  var path = require( 'path' );
  var fs = require("fs");
  var finalresults = {};
  fs.readdirSync(normalizedPath).forEach(function(file) {
    if (!fs.statSync(normalizedPath + '/' + file).isDirectory()) {
      return ;
    };
    if (filterdir && file != filterdir) {
      return ;
    }
    var modulename = path.basename(file);
    if (!fs.existsSync(path.resolve( basedir + '/' + file + '/'+ modulename +'.js' ))) {
      return ;
    }
    var lib = require(path.resolve( basedir + '/' + file + '/'+ modulename +'.js' ));
    var ret;
    if (typeof callback == 'string') {
      if (lib[callback]) {
        ret = lib[callback].apply(lib, callarguments);
      }
      else {
        ret = {};
      }
    }
    else {
      ret = nodeproxy(callback, lib).apply(lib, [lib].concat(callarguments));
    }

    var addGmodule = function(tmpVal) {
      Object.keys(tmpVal).forEach(function(rete) {
        tmpVal[rete].gmodule = modulename;
        if (tmpVal[rete]['children']) {
          addGmodule(tmpVal[rete]['children']);
        }
      });
    }
    addGmodule(ret);

    extend(finalresults, ret);
  });
  return finalresults;
}

GM.argv = require('minimist')(process.argv.slice(2));

/* TODO: Move to repository:
 * Export variable to bash
 */
GM.exportbash = function(v) {
  Object.keys(v).forEach( i => {
    if (typeof(v[i]) != "object") {
      console.log(`${i}="${v[i]}"`);
    }
    else {
      // Export object
      console.log(`declare -A ${i}`);
      console.log(`${i}=(`);
      Object.keys(v[i]).forEach( ii => {
        if (typeof(v[i][ii]) != "object") {
          console.log(`  [${ii}]="${v[i][ii]}"`);
        }
      });
      console.log(`)`);
    }
  });
}

global.GM = GM;
module.exports = {};
