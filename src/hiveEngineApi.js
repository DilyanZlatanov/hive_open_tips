import axios from 'axios'
import pRetry from 'p-retry'
import pTimeout from 'p-timeout'


const endpoints = [
  'https://engine.rishipanthee.com/contracts',
  'https://engine.deathwing.me/contracts',
  'https://herpc.dtools.dev/contracts',
  'https://api.primersion.com/contracts'
  // 'https://api.hive-engine.com/rpc/contracts'
]


export class HiveEngineApi {
  config = {
    endpoints: [...endpoints],
    timeout: 5000,
    retries: 3
  }

  rpcCallId = 0
  currentEndpoint = this.config.endpoints[Math.floor(Math.random() * this.config.endpoints.length)]

  selectNextNode = () => {
    const index = endpoints.findIndex((n) => n === this.currentEndpoint) + 1
    this.currentEndpoint = endpoints[index % endpoints.length]
  }

  /* SDK instance configuration */
  setConfig = (newConfig) => {
    this.config = {
      ...this.config,
      ...newConfig
    }
  }

  getTransaction = async (trxId) => {
    return pRetry(
      () =>
        pTimeout(
          axios.post('https://engine.rishipanthee.com/blockchain', {
            id: this.rpcCallId++,
            jsonrpc: '2.0',
            method: 'getTransactionInfo',
            params: {
              txid: trxId
            }
          }),
          { milliseconds: this.config.timeout }
        ),
      {
        retries: this.config.retries,
        onFailedAttempt: () => this.selectNextNode()
      }
    ).then((response) => response.data)
  }

  /** Generic utility methods */
  findOne = async (contract, table, query, indexes = []) => {
    return pRetry(
      () =>
        pTimeout(
          axios.post(this.currentEndpoint, {
            id: this.rpcCallId++,
            jsonrpc: '2.0',
            method: 'findOne',
            params: {
              contract: contract,
              table: table,
              query: query,
              limit: 1,
              offset: 0,
              ...(indexes && indexes.length ? { indexes: indexes } : {})
            }
          }),
          { milliseconds: this.config.timeout }
        ),
      {
        retries: this.config.retries,
        onFailedAttempt: () => this.selectNextNode()
      }
    ).then((response) => response.data?.result)
  }

  findMany = async (
    contract,
    table,
    query,
    limit = 1000,
    offset = 0,
    indexes = []
  ) => {
    return pRetry(
      () =>
        pTimeout(
          axios.post(this.currentEndpoint, {
            id: this.rpcCallId++,
            jsonrpc: '2.0',
            method: 'find',
            params: {
              contract: contract,
              table: table,
              query: query,
              limit: limit,
              offset: offset,
              ...(indexes && indexes.length ? { indexes: indexes } : {})
            }
          }),
          { milliseconds: this.config.timeout }
        ),
      {
        retries: this.config.retries,
        onFailedAttempt: () => this.selectNextNode()
      }
    ).then((response) => response.data?.result)
  }

  findAll = async (
    contract,
    table,
    query,
    indexes = []
  ) => {
    let results = []

    while (true) {
      const records = await this.findMany(contract, table, query, 1000, results.length, indexes)
      results = results.concat(records)

      if (records.length < 1000) {
        break
      }
    }

    return results
  }

  /* Helper methods to simplify common API calls */
  getToken = async (token) => {
    return this.findOne('tokens', 'tokens', { symbol: token })
  }
  getPool = async (pair) => {
    return this.findOne('marketpools', 'pools', { tokenPair: pair })
  }
  getPools = async (pairs) => {
    return this.findMany('marketpools', 'pools', { tokenPair: { $in: pairs } })
  }
  getAccountTokensBalances = async (account, token) => {
    return this.findOne('tokens', 'balances', {
      account: account,
      symbol: token
    })
  }
}

export const hiveEngineApi = new HiveEngineApi()
export default hiveEngineApi
