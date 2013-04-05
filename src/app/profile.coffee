character = require './character'
browser = require './browser'
helpers = require './helpers'

module.exports.app = (appExports, model) ->
  user = model.at('_user')

  appExports.profileAddWebsite = (e, el) ->
    newWebsite = model.get('_newProfileWebsite')
    return if /^(\s)*$/.test(newWebsite)
    user.unshift 'profile.websites', newWebsite
    model.set '_newProfileWebsite', ''

  appExports.profileEdit = (e, el) -> model.set '_profileEditing', true
  appExports.profileSave = (e, el) -> model.set '_profileEditing', false
  appExports.profileRemoveWebsite = (e, el) ->
    sites = user.get 'profile.websites'
    i = sites.indexOf $(el).attr('data-website')
    sites.splice(i,1)
    user.set 'profile.websites', sites

  appExports.profileChangeActive = (e, el) ->
    uid = $(el).attr('data-uid')
    model.ref '_profileActive', model.at("users.#{uid}")
    model.set '_profileActiveMain', user.get('id') is uid
    model.set '_profileActiveUsername', helpers.username model.get('_profileActive.auth')
    browser.setupTooltips(model)

