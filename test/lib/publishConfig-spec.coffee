async = require 'async'
PublishConfig = require '../../lib/publishConfig'
Subscriber = require '../../lib/Subscriber'
Database = require '../test-database'
clearCache = require '../../lib/clearCache'

describe.only 'PublishConfig', ->
  beforeEach (done) ->
    uuids = [
      'uuid-device-being-configged'
      'uuid-interested-device'
      'uuid-uninterested-device'
    ]
    async.each uuids, clearCache, done

  beforeEach (done) ->
    Database.open (error, @database) => done error

  beforeEach (done) ->
    @database.devices.insert
      uuid: 'uuid-device-being-configged'
      meshblu:
        configForward: [
          {uuid: 'uuid-interested-device'}
          {uuid: 'uuid-uninterested-device'}
        ]
    , done

  beforeEach ->
    @sut = new PublishConfig
      uuid: 'uuid-device-being-configged'
      config: {foo: 'bar'}
      database: @database

  describe 'when called', ->
    beforeEach (done)->
      subscriber = new Subscriber namespace: 'meshblu'
      subscriber.once 'message', (type, @message) =>

      subscriber.subscribe 'config', 'uuid-device-being-configged', =>
        @sut.publish done

    it "should publish the config to 'uuid-device-being-configged'", ->
      expect(@message).to.deep.equal foo: 'bar'

  describe "when another device is in the configForward list", ->
    beforeEach (done) ->
      @database.devices.insert
        uuid: 'uuid-interested-device'
        sendWhitelist: ['uuid-device-being-configged']
      , done

    beforeEach (done) ->
      subscriber = new Subscriber namespace: 'meshblu'
      subscriber.once 'message', (type, @config) =>
        done()

      subscriber.subscribe 'config', 'uuid-interested-device', =>
        @sut.publish()

    it "should publish it's config to a device in to it", ->
      expect(@config).to.deep.equal foo: 'bar'

  describe "when forwarding a config to a device that doesn't want it", ->
    beforeEach (done) ->
      @database.devices.insert
        uuid: 'uuid-uninterested-device'
        sendWhitelist: []
      , done

    beforeEach (done) ->
      @configEvent = sinon.spy()
      subscriber = new Subscriber namespace: 'meshblu'
      subscriber.once 'message', @configEvent
      subscriber.subscribe 'config', 'uuid-uninterested-device', =>
        @sut.publish done

    it 'should not send a message to that device', ->
      expect(@configEvent).to.not.have.been.called

  describe "when forwarding the config to oneself", ->
    beforeEach (done) ->
      @database.devices.insert
        uuid: 'uuid-interested-device'
        sendWhitelist: ['uuid-device-being-configged', 'uuid-interested-device']
        meshblu:
          configForward: [
            uuid: 'uuid-interested-device'
          ]
      , done

    beforeEach (done) ->
      @configEvent = sinon.spy()
      @subscriber = new Subscriber namespace: 'meshblu'
      @subscriber.on 'message', @configEvent
      @subscriber.subscribe 'config', 'uuid-interested-device', =>
        @sut.publish done

    afterEach ->
      @subscriber.removeAllListeners()

    it 'should break free from the infinite loop and get here', ->
      expect(@configEvent).to.have.been.calledOnce