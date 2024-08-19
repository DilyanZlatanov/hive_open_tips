//Node.js app

import cron from 'node-cron'
import hiveEngineApi from './hiveEngineApi.js'
import { Sequelize, QueryTypes } from 'sequelize'


/* Establish db connection via the peer authentication method */

//Switch OS user
import process from 'node:process';

if (process.getuid && process.setuid) {
  console.log(`Current uid: ${process.getuid()}`);
  try {
    process.setuid('scheduler');
    console.log(`New uid: ${process.getuid()}`);
  } catch (err) {
    console.error(`Failed to set uid: ${err}`);
  }
}

//Connect to the local db
//Reference: https://github.com/brianc/node-postgres/issues/613
const sequelize = new Sequelize('hive_open_tips', 'scheduler', undefined, {
  host: '/var/run/postgresql',
  dialect: 'postgres'
})

try {
  sequelize.authenticate();
  console.log('Local database connection established successfully.')
} catch (error) {
  console.error('Unable to connect to the database:', error)
}

// This is for preventing docker container to stop.
cron.schedule('* * * * *', async () => {
  console.log("Starting validation of HiveEngine trasactions")
    
  var results = await sequelize.query(
    `SELECT *
     FROM unverified_transfers
     ORDER BY hafsql_op_id ASC
     LIMIT 500`,
    { type: QueryTypes.SELECT }
  );

  for(const result of results) {
    //Validate the transfer
    console.log(result.trx_id)
    var trx_info = await hiveEngineApi.getTransaction(
      result.trx_id
    )
    console.log(trx_info)
  }

  });