var Command, Transformation, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Command = require('../Command');

Transformation = (function(_super) {
  __extends(Transformation, _super);

  function Transformation() {
    _ref = Transformation.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  Transformation.prototype.type = 'Transformation';

  Transformation.Matrix = require('../../vendor/gl-matrix');

  Transformation.prototype.matrix = function() {};

  Transformation.prototype.matrix3d = function() {};

  Transformation.prototype._transform = function(matrix, method, a, b, c) {
    if (matrix.length === 9) {
      return mat3[method](matrix, matrix, a, b, c);
    } else {
      return mat4[method](matrix, matrix, a, b, c);
    }
  };

  Transformation.prototype._transform3d = function(matrix, method, a, b, c) {
    if (matrix.length === 9) {
      matrix = mat4.fromMat3(matrix);
    }
    return mat4[method](matrix, matrix, a, b, c);
  };

  Transformation.prototype.translate = [
    function(matrix, x, y) {
      if (y == null) {
        y = x;
      }
      return this._transform(matrix, 'translate', [x, y]);
    }, {
      "3d": function(matrix, x, y, z) {
        if (y == null) {
          y = x;
        }
        if (z == null) {
          z = 0;
        }
        if (z === 0) {
          return this._transform(matrix, 'translate', [x, y]);
        } else {
          return this._transform3d(matrix, 'translate', [x, y, z]);
        }
      },
      x: function(matrix, x) {
        return this._transform(matrix, 'translate', [x, 1, 1]);
      },
      y: function(matrix, y) {
        return this._transform(matrix, 'translate', [1, y, 1]);
      },
      z: function(matrix, z) {
        return this._transform3d(matrix, 'translate', [1, 1, z]);
      }
    }
  ];

  Transformation.prototype.rotate = [
    function(matrix, x, y, angle) {
      return this._transform(matrix, 'rotate', [x, y], angle);
    }, {
      "3d": function(matrix, x, y, z, angle) {
        return this._transform3d(matrix, 'rotate', [x, y, z], angle);
      },
      x: function(matrix, x) {
        return this._transform(matrix, 'rotateX', x);
      },
      y: function(matrix, y) {
        return this._transform(matrix, 'rotateY', y);
      },
      z: function(matrix, z) {
        return this._transform3d(matrix, 'rotateZ', z);
      }
    }
  ];

  Transformation.prototype.scale = [
    function(matrix, x, y, z) {
      if (y == null) {
        y = x;
      }
      if (z == null) {
        z = 1;
      }
      if (z === 1) {
        return this._transform(matrix, 'scale', [x, y]);
      } else {
        return this._transform3d(matrix, 'scale', [x, y, z]);
      }
    }, {
      x: function(matrix, x) {
        return this._transform(matrix, 'scale', [x, 1, 1]);
      },
      y: function(matrix, y) {
        return this._transform(matrix, 'scale', [1, y, 1]);
      },
      z: function(matrix, z) {
        return this._transform3d(matrix, 'scale', [1, 1, z]);
      }
    }
  ];

  return Transformation;

})(Command);

/*
  skew: [
    x:
    y:
  ]
*/
