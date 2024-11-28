This API is for collecting and providing statistics for specific type of transactions.
Logic behind the code:
1. Fetch data for transactions from source database.
2. Filter data to extract only transactions that match target criteria.
3. Validate if the transactions are real and really happened, using NODES.
4. Save validated transactions into local database.

Used technologies: PL/pgSQL, JavaScrips
