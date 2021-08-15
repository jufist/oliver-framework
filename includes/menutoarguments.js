var m = {};

m.init = function (program, menus) {
  var outs = {};
  var parent;
  Object.keys(menus).forEach(function (e) {
    var mn = menus[e];
    if (mn.children) {
      // Build children
      var childquestions = {};
      Object.keys(mn.children).forEach(function (childe) {
        var childmn = mn.children[childe];
        var op;
        op = childmn['gmodule'] + '' + childe;
        outs[op] = childmn;
      });
    }
  });
  m.arguments = outs;
  m.addProgram(program);
};

m.addProgram = function (program) {
  var i = 0;
  Object.keys(m.arguments).forEach(function (e) {
    var arg = m.arguments[e];
    i++;
    program.option(`-z${i}, ` + '--' + e, arg['title']);
  });
};

m.handle = async (program) => {
  var ret = false;
  for (const e of Object.keys(m.arguments)) {
    var arg = m.arguments[e];
    if (program[e]) {
      var cb = await arg.callbackfinal();
      ret = true;
    }
  }
  return ret;
};

module.exports = m;
