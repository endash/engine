var Assignment, Command, _ref, _ref1,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Command = require('../concepts/Command');

Assignment = (function(_super) {
  __extends(Assignment, _super);

  function Assignment() {
    _ref = Assignment.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  Assignment.prototype.type = 'Assignment';

  Assignment.prototype.signature = [
    [
      {
        object: ['Query', 'Selector']
      }
    ], {
      property: ['String'],
      value: ['Variable']
    }
  ];

  return Assignment;

})(Command);

Assignment.Unsafe = (function(_super) {
  __extends(Unsafe, _super);

  function Unsafe() {
    _ref1 = Unsafe.__super__.constructor.apply(this, arguments);
    return _ref1;
  }

  Unsafe.prototype.signature = [
    [
      {
        object: ['Query', 'Selector']
      }
    ], {
      property: ['String'],
      value: ['Any']
    }
  ];

  Unsafe.prototype.advices = [
    function(engine, operation, command) {
      var parent, rule;
      parent = operation;
      rule = void 0;
      while (parent.parent) {
        if (!rule && parent[0] === 'rule') {
          rule = parent;
        }
        parent = parent.parent;
      }
      operation.index = parent.rules = (parent.rules || 0) + 1;
      if (rule) {
        (rule.properties || (rule.properties = [])).push(operation.index);
      }
    }
  ];

  return Unsafe;

})(Assignment);

module.exports = Assignment;