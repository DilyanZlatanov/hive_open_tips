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

// Run query for validation.
cron.schedule('* * * * *', async () => {
  console.log("Starting validation of HiveEngine transactions");

  var results = await sequelize.query(
    `SELECT *
     FROM unverified_transfers
     ORDER BY hafsql_op_id ASC
     LIMIT 500`,
    { type: QueryTypes.SELECT }
  );

  for (const result of results) {

    // Validate the transfer
    var trx_info = await hiveEngineApi.getTransaction(result.trx_id);

    // Save validated records from unverified_transfers table to hive_open_tips table
    if (trx_info && trx_info.result) {
      if (result.sender == trx_info.result.sender
        && trx_info.result.contract == 'tokens'
        && trx_info.result.action == 'transfer') {

        await sequelize.query(
          `INSERT INTO hive_open_tips (
            hafsql_op_id,
            sender,
            receiver,
            amount,
            token,
            timestamp,
            platform,
            author,
            permlink,
            memo,
            parent_author,
            parent_permlink,
            author_permlink
          )
          VALUES (
            :result_hafsql_op_id,
            :result_sender,
            :result_receiver,
            :result_amount,
            :result_token,
            :result_timestamp,
            :result_platform,
            :result_author,
            :result_permlink,
            :result_memo,
            :result_parent_author,
            :result_parent_permlink,
            :result_author_permlink
          )`,
          {
            replacements: {
              result_hafsql_op_id: result.hafsql_op_id,
              result_sender: result.sender,
              result_receiver: result.receiver,
              result_amount: result.amount,
              result_token: result.token,
              result_timestamp: result.timestamp,
              result_platform: result.platform,
              result_author: result.author,
              result_permlink: result.permlink,
              result_memo: result.memo,
              result_parent_author: result.parent_author,
              result_parent_permlink: result.parent_permlink,
              result_author_permlink: result.author_permlink
            }
          }
        );
        console.log(`Record with hafsql_op_id ${result.hafsql_op_id} successfully inserted into hive_open_tips table`);
      }
    }

    // Delete record from unverified_transfers after validation 
    await sequelize.query(
      `DELETE FROM unverified_transfers
        WHERE hafsql_op_id = :result_op_id`,
      { replacements: { result_op_id: result.hafsql_op_id } }
    );
    console.log(`Record with hafsql_op_id ${result.hafsql_op_id} deleted successfully from unverified_transfers table`);
  }
});
