path = require 'path'
through2 = require 'through2'
git = require 'git-promise'
Promise = require 'promise'
_ = find: require 'lodash.find'

# Requires: []
# Must run before 'html'
emailRegExp = /email=\[([^\[\]]*)\]/i
dateRegExp = /date=\[([^\[\]]*)\]/i

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

    parseLine = (fallbackEmail) ->
        (str) ->
            result = { }
            try result.email = str.match(emailRegExp)[1].toLowerCase().trim()
            try result.date = parseDate str.match(dateRegExp)[1]
            result

    getAuthor = (email) ->
        (_.find authors, { email }) || { email }

    processFile = (file, enc, done) ->
        filename = file.basename || path.basename file.path

        cmdCreated =
            "git log -1 --pretty=format:'email=[%ae] date=[%cd]'
            --diff-filter=A #{filename}"

        cmdModified =
            "git log -1 --pretty=format:'email=[%ae] date=[%cd]'
            --diff-filter=M #{filename}"

        getCreated =
            git(cmdCreated, cwd: repo)
            .then parseLine authors[0].email

        getModified =
            git(cmdModified, cwd: repo)
            .then parseLine authors[0].email

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