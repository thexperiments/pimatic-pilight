module.exports = (env) ->

  assert = env.require "cassert"
  proxyquire = env.require 'proxyquire'
  Q = env.require 'q'

  describe "pimatic-pilight", ->

    env.EverSocket = (
      class EverSocketDummy extends require('events').EventEmitter
        connect: (port, host) -> 
          @connectCalled = true
          assert host?
          assert port? and not isNaN port
      )

    pilightPlugin = require('pimatic-pilight') env

    framework = {}
    pilightSwitch = null
    pilightDimmer = null
    pilightTemperatureSensor = null

    describe "PilightPlugin", ->
      describe '#init()', ->
        it "should connect", ->
          pilightPlugin.init null, framework, 
            timeout: 1000
            debug: false
          assert pilightPlugin.client.connectCalled
          
        it "should send welcome", ->
          pilightPlugin.client.write = (data) ->
            @writeCalled = true
            msg = JSON.parse data
            assert msg.message is "client gui" 

          pilightPlugin.client.emit "reconnect"
          assert pilightPlugin.client.writeCalled
          assert pilightPlugin.client.state is "welcome"

      describe "#onReceive()", ->
        it "should request config", ->
          pilightPlugin.client.writeCalled = false
          pilightPlugin.client.write = (data) ->
            @writeCalled = true
            msg = JSON.parse data
            assert msg.message is "request config" 

          pilightPlugin.client.emit 'data', JSON.stringify(
            message: "accept client"
          ) + "\n"

          assert pilightPlugin.client.writeCalled 
          assert pilightPlugin.client.state is "connected"

        it "should create a PilightSwitch", ->
          sampleConfigMsg =
            config:
              living:
                name: "Living"
                order: 1
                bookshelve:
                  type: 1
                  name: "Book Shelve Light"
                  protocol: ["kaku_switch"]
                  id: [
                    id: 1234
                    unit: 0
                  ]
                  state: "off"
            version: [
              "2.0"
              "2.0"
            ]

          framework.getDeviceByIdCalled = false
          framework.getDeviceById = (id) ->
            assert id is "pilight-living-bookshelve"
            @getDeviceByIdCalled = true
            return null

          framework.registerDeviceCalled = false
          framework.registerDevice = (device) ->
            @registerDeviceCalled = true
            assert device?
            assert device instanceof pilightPlugin.PilightSwitch
            pilightSwitch = device
            assert pilightSwitch._constructorCalled
            assert pilightSwitch.config.device is "bookshelve"
            assert pilightSwitch.config.location is "living"

          framework.addDeviceToConfigCalled = false
          framework.addDeviceToConfig = (config) ->
            @addDeviceToConfigCalled = true
            assert config?

          framework.saveConfigCalled = false
          framework.saveConfig = () ->
            @saveConfigCalled = true
            assert pilightSwitch._state is false

          pilightPlugin.client.emit 'data', JSON.stringify(sampleConfigMsg) + '\n'

          assert framework.getDeviceByIdCalled
          assert framework.registerDeviceCalled
          assert framework.addDeviceToConfigCalled
          assert framework.saveConfigCalled

        it "should create a PilightDimmer", ->
          sampleConfigMsg =
            config:
              living:
                name: "Living"
                dimmer:
                  type: 2
                  name: "Dimmer"
                  protocol: ["generic_dimmer"]
                  id: [id: 1234]
                  state: "on"
                  dimlevel: 10
            version: [
              "2.0"
              "2.0"
            ]

          framework.getDeviceByIdCalled = false
          framework.getDeviceById = (id) ->
            assert id is "pilight-living-dimmer"
            @getDeviceByIdCalled = true
            return null

          framework.registerDeviceCalled = false
          framework.registerDevice = (device) ->
            @registerDeviceCalled = true
            assert device?
            assert device instanceof pilightPlugin.PilightDimmer
            pilightDimmer = device
            assert pilightDimmer._constructorCalled
            assert pilightDimmer.config.device is "dimmer"
            assert pilightDimmer.config.location is "living"

          framework.addDeviceToConfigCalled = false
          framework.addDeviceToConfig = (config) ->
            @addDeviceToConfigCalled = true
            assert config?

          framework.saveConfigCalled = false
          framework.saveConfig = () ->
            @saveConfigCalled = true
            assert pilightDimmer._dimlevel is 10
            assert pilightDimmer._state is on

          pilightPlugin.client.emit 'data', JSON.stringify(sampleConfigMsg) + '\n'

          assert framework.getDeviceByIdCalled
          assert framework.registerDeviceCalled
          assert framework.addDeviceToConfigCalled
          assert framework.saveConfigCalled

        it "should create a PilightTemperatureSensor", ->
          sampleConfigMsg =
            config:
             living:
              name: "Living"
              weather:
                type: 3
                name: "Weather"
                protocol: ["generic_weather"]
                id: [id: 100]
                temperature: 2300
                humidity: 7600
                battery: 0
                settings: 
                  decimals: 2
            version: [
              "2.0"
              "2.0"
            ]

          framework.getDeviceByIdCalled = false
          framework.getDeviceById = (id) ->
            assert id is "pilight-living-weather"
            @getDeviceByIdCalled = true
            return null

          framework.registerDeviceCalled = false
          framework.registerDevice = (device) ->
            @registerDeviceCalled = true
            assert device?
            assert device instanceof pilightPlugin.PilightTemperatureSensor
            pilightTemperatureSensor = device
            assert pilightTemperatureSensor._constructorCalled
            assert pilightTemperatureSensor.config.device is "weather"
            assert pilightTemperatureSensor.config.location is "living"

          framework.addDeviceToConfigCalled = false
          framework.addDeviceToConfig = (config) ->
            @addDeviceToConfigCalled = true
            assert config?

          framework.saveConfigCalled = false
          framework.saveConfig = () ->
            @saveConfigCalled = true
            assert pilightTemperatureSensor.temperature is 23
            assert pilightTemperatureSensor.humidity is 76

          pilightPlugin.client.emit 'data', JSON.stringify(sampleConfigMsg) + '\n'

          assert framework.getDeviceByIdCalled
          assert framework.registerDeviceCalled
          assert framework.addDeviceToConfigCalled
          assert framework.saveConfigCalled

    describe "PilightSwitch", ->  
      describe "#turnOn()", ->
        it "should send turnOn", (finish)->
          framework.saveConfigCalled = false
          framework.saveConfig = () ->
            @saveConfigCalled = true
          gotData = false
          pilightPlugin.client.write = (data) ->
            gotData = true
            msg = JSON.parse data
            assert msg?
            assert msg.message is 'send'
            assert msg.code?
            assert msg.code.location is 'living'
            assert msg.code.device is 'bookshelve'
            assert msg.code.state is "on"

            setTimeout( () ->
              msg = 
                origin: "config"
                type: 1
                devices:
                  living: ["bookshelve"]
                values:
                  state: "on"
              pilightPlugin.client.emit 'data', JSON.stringify(msg) + "\n"
            , 1)

          pilightSwitch.turnOn().then( ->
            assert gotData
            finish()
          ).done()

        it "turnOn should timeout", (finish) ->
          this.timeout 5000
          pilightPlugin.config.timeout = 200

          gotData = false
          pilightPlugin.client.write = (data) ->
            gotData = true
            msg = JSON.parse data
            assert msg?
            assert msg.message is 'send'
            assert msg.code?
            assert msg.code.location is 'living'
            assert msg.code.device is 'bookshelve'

          pilightSwitch.turnOn().then( -> 
            assert false
          ).catch( (error) ->
            assert error? 
            finish() 
          ).done()

      describe "#turnOff()", ->
        it "should send turnOff", (finish)->
          this.timeout 1000

          framework.saveConfigCalled = false
          framework.saveConfig = () ->
            @saveConfigCalled = true

          gotData = false
          pilightPlugin.client.write = (data) ->
            gotData = true
            msg = JSON.parse data
            assert msg?
            assert msg.message is 'send'
            assert msg.code?
            assert msg.code.location is 'living'
            assert msg.code.device is 'bookshelve'
            assert msg.code.state is "off"

            setTimeout( () ->
              msg = 
                origin: "config"
                type: 1
                devices:
                  living: ["bookshelve"]
                values:
                  state: "off"
              pilightPlugin.client.emit 'data', JSON.stringify(msg) + "\n"
            , 1)

          pilightSwitch.turnOff().then( ->
            assert gotData
            finish()
          ).done()

    describe "PilightDimmer", ->  
      describe "#turnOn()", ->
        it "should send turnOn", (finish)->
          framework.saveConfigCalled = false
          framework.saveConfig = () ->
            @saveConfigCalled = true

          gotData = false
          pilightPlugin.client.write = (data) ->
            gotData = true
            msg = JSON.parse data
            assert msg?
            assert msg.message is 'send'
            assert msg.code?
            assert msg.code.location is 'living'
            assert msg.code.device is 'dimmer'
            assert msg.code.state is "on"
            assert msg.values?
            assert msg.values.dimlevel is "100"

            setTimeout( () ->
              msg = 
                origin: "config"
                type: 1
                devices:
                  living: ["dimmer"]
                values:
                  state: "on"
                  dimlevel: "100"
              pilightPlugin.client.emit 'data', JSON.stringify(msg) + "\n"
            , 1)

          pilightDimmer.turnOn().then( ->
            assert gotData
            assert pilightDimmer._dimlevel is 100
            assert pilightDimmer._state is on
            finish()
          ).done()

      describe "#turnOff()", ->
        it "should send turnOff", (finish)->
          this.timeout 1000


          framework.saveConfigCalled = false
          framework.saveConfig = () ->
            @saveConfigCalled = true

          gotData = false
          pilightPlugin.client.write = (data) ->
            gotData = true
            msg = JSON.parse data
            assert msg?
            assert msg.message is 'send'
            assert msg.code?
            assert msg.code.location is 'living'
            assert msg.code.device is 'dimmer'
            assert msg.code.state is 'off'
            assert msg.values?
            assert msg.values.dimlevel is "0"

            setTimeout( () ->
              msg = 
                origin: "config"
                type: 1
                devices:
                  living: ["dimmer"]
                values:
                  state: "off"
                  dimlevel: "0"
              pilightPlugin.client.emit 'data', JSON.stringify(msg) + "\n"
            , 1)

          pilightDimmer.turnOff().then( ->
            assert gotData
            assert pilightDimmer._dimlevel is 0
            assert pilightDimmer._state is off
            finish()
          ).done()


      describe "#changeDimlevelTo()", ->

        it "should change the dimlevel to 20", (finish)->

          framework.saveConfigCalled = false
          framework.saveConfig = () ->
            @saveConfigCalled = true

          gotData = false
          pilightPlugin.client.write = (data) ->
            gotData = true
            msg = JSON.parse data
            assert msg?
            assert msg.message is 'send'
            assert msg.code?
            assert msg.code.location is 'living'
            assert msg.code.device is 'dimmer'
            assert msg.values?
            assert msg.values.dimlevel is "20"

            setTimeout( () ->
              msg = 
                origin: "config"
                type: 1
                devices:
                  living: ["dimmer"]
                values:
                  state: "off"
                  dimlevel: "20"
              pilightPlugin.client.emit 'data', JSON.stringify(msg) + "\n"
            , 1)

          pilightDimmer.changeDimlevelTo(20).then( ->
            assert gotData
            assert pilightDimmer._dimlevel is 20
            assert pilightDimmer._state is on
            finish()
          ).done()

        it "turnOn should timeout", (finish) ->
          this.timeout 5000
          pilightPlugin.config.timeout = 200

          gotData = false
          pilightPlugin.client.write = (data) ->
            gotData = true
            msg = JSON.parse data
            assert msg?
            assert msg.message is 'send'
            assert msg.code?
            assert msg.code.location is 'living'
            assert msg.code.device is 'dimmer'

          pilightDimmer.turnOn().then( -> 
            assert false
          ).catch( (error) ->
            assert error? 
            finish() 
          ).done()
