path = require 'path'
through2 = require 'through2'
git = require 'git-promise'
Promise = require 'promise'
_ = require 'lodash'

# Requires: []

module.exports = (repo, authors) ->
    if not authors # @TODO
        console.log 'WARN: author information not provided'

    if typeof repo isnt 'string'
        throw new TypeError 'You must specify a path to git
        repository to extract metadata from'

    parseDate = (dateStr) ->
        if typeof dateStr is 'string'
            new Date dateStr
        else
            throw new TypeError 'Date must be a string'

    parseLine = (str) ->
        matches = str.match /^(\S*@\S*\.\S*)\s(.*)$/i
        if matches
            email = matches[1].toLowerCase().trim()
            date = parseDate matches[2]
            return { email, date }
        return null

    getAuthor = (email) ->
        (_.find authors, { email }) || { email }

    processFile = (file, enc, done) ->
        filename = file.basename || path.basename file.path

        getCreated =
            git("git log -1 --pretty=format:'%ae %cd'
                 --diff-filter=A #{filename}", cwd: repo)
            .then parseLine

        getModified =
            git("git log -1 --pretty=format:'%ae %cd'
                 --diff-filter=M #{filename}", cwd: repo)
            .then parseLine

        Promise.all [getCreated, getModified]
        .then (array) ->
            [ created, modified ] = array

            file.created = created if created
            file.modified = modified if modified

            if created.email
                file.author = getAuthor created.email

                if modified and created.email isnt modified.email
                    file.contributors = getAuthor modified.email
            else
                # @TODO
                console.log '[git-metadata] WARN: No author information found'

            done null, file
        .catch (err) ->
            # @TODO: debug
            console.log 'Error in metadata', err
            done e, file

    through2.obj processFile