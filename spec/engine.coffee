Engine = require 'gss-engine/lib/Engine.js'

describe 'GSS engine', ->
  container = null
  gss = null

  before ->
    fixtures = document.getElementById 'fixtures'
    container = document.createElement 'div'
    fixtures.appendChild container
    container.innerHTML = """
      <button id="button1">One</button>
      <button id="button2">Second</button>
      <button id="button3">Three</button>
      <button id="button4">4</button>
    """
    gss = new Engine '../browser/gss-engine/worker/gss-solver.js', container

  after (done) ->
    gss.stop()
    done()

  describe 'when initialized', ->
    it 'should be bound to the DOM container', ->
      chai.expect(gss.container).to.eql container
    it 'should not hold variables', ->
      chai.expect(gss.variables).to.be.an 'object'
      chai.expect(gss.variables).to.be.empty
    it 'should not hold elements', ->
      chai.expect(gss.elements).to.be.an 'object'
      chai.expect(gss.elements).to.be.empty
    it 'should not hold a worker', ->
      chai.expect(gss.worker).to.be.a 'null'
    it 'should pass the container to its DOM getter', ->
      chai.expect(gss.getter).to.be.an 'object'
      chai.expect(gss.getter.container).to.eql gss.container
    it 'should pass the container to its DOM setter', ->
      chai.expect(gss.setter).to.be.an 'object'
      chai.expect(gss.setter.container).to.eql gss.container
  describe 'with rule #button1[width] == #button2[width]', ->
    ast =
      selectors: [
        '#button1'
        '#button2'
      ]
      commands: [
        ['get', '#button1[width]', 'width', ['$id', '#button1']]
        ['get', '#button2[width]', 'width', ['$id', '#button2']]
        ['eq', ['get', '#button1[width]'], ['get', '#button2[width]']]
      ]
    button1 = null
    button2 = null
    it 'before solving the second button should be wider', ->
      button1 = container.querySelector '#button1'
      button2 = container.querySelector '#button2'
      chai.expect(button2.getBoundingClientRect().width).to.be.above button1.getBoundingClientRect().width
    it 'after solving the buttons should be of equal width', (done) ->
      gss.onSolved = (values) ->
        chai.expect(values).to.be.an 'object'
        chai.expect(values['#button1[width]']).to.equal values['#button2[width]']
        chai.expect(button1.getBoundingClientRect().width).to.equal values['#button1[width]']
        chai.expect(button2.getBoundingClientRect().width).to.equal values['#button2[width]']
        done()
      gss.onError = (error) ->
        chai.assert("#{event.message} (#{event.filename}:#{event.lineno})").to.equal ''
        gss.onError = null
        done()
      gss.run ast
  describe 'with rule #button3[width] == #button4[height]', ->
    ast =
      selectors: [
        '#button3'
        '#button4'
      ]
      commands: [
        ['get', '#button3[width]', 'width', ['$id', '#button3']]
        ['get', '#button4[height]', 'height', ['$id', '#button4']]
        ['eq', ['get', '#button3[width]'], ['get', '#button4[height]']]
      ]
    button3 = null
    button4 = null
    it 'before solving the buttons should be of equal height', ->
      button3 = container.querySelector '#button3'
      button4 = container.querySelector '#button4'
      chai.expect(button3.getBoundingClientRect().height).to.equal button4.getBoundingClientRect().height
    it 'after solving the second button should be taller', (done) ->
      gss.onSolved = (values) ->
        chai.expect(values).to.be.an 'object'
        rounded =
          calc_b4h: Math.round values['#button4[height]']
          calc_b3w: Math.round values['#button3[width]']
          real_b4h: Math.round button4.getBoundingClientRect().height
          real_b3w: Math.round button3.getBoundingClientRect().width

        chai.expect(rounded.calc_b3w).to.equal rounded.calc_b4h
        chai.expect(rounded.real_b3w).to.equal rounded.calc_b3w
        chai.expect(rounded.real_b4h).to.equal rounded.calc_b4h
        chai.expect(button4.getBoundingClientRect().height).to.be.above button3.getBoundingClientRect().height
        done()
      gss.onError = (error) ->
        chai.assert("#{event.message} (#{event.filename}:#{event.lineno})").to.equal ''
        gss.onError = null
        done()
      gss.run ast