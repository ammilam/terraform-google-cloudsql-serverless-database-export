const {
    google
} = require('googleapis')
const {
    GoogleAuth
} = require('google-auth-library')
const sqladmin = google.sqladmin('v1beta4')

// exports.backup => creates cloud function entrypoint
exports.backup = async (event, context) => {

    // auth with cloud function service account, is a requirement of hitting the DB via googleapis client library
    const auth = new GoogleAuth({
        scopes: [
            'https://www.googleapis.com/auth/cloud-platform',
        ]
    })
    const authRes = await auth.getApplicationDefault()

    // create variable to use as export name
    var timestamp = Date.now()
    var date = new Date(timestamp).toISOString().split(".")[0]

    console.info(`backing up ${process.env.DATABASE_NAME}`)

    // builds request body, used to initiate a database export
    const request = {
        auth: authRes.credential,
        project: process.env.PROJECT_ID,
        instance: process.env.DATABASE_INSTANCE,
        resource: {
            exportContext: {
                kind: 'sql#exportContext',
                databases: [process.env.DATABASE_NAME],
                fileType: 'SQL',
                uri: `${process.env.BACKUP_PATH}/` + date + '.sql.gz'
            }
        }
    }

    // export the database using sqladmin via googleapis client library
    sqladmin.instances.export(request, (err, res) => {
        if (err) console.error(err)
        if (res) console.info(`finished backing up ${process.env.DATABASE_NAME}`)
        if (res) console.info(`file saved at ${path}`)
    })
}