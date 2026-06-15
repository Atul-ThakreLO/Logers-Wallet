export const SUBGRAPH_URL = process.env.NEXT_PUBLIC_SUBGRAPH_URL ?? process.env.SUBGRAPH_URL ?? "";

export async function querySubgraph<T>(
  query: string,
  variables?: Record<string, unknown>
): Promise<T> {
  if (!SUBGRAPH_URL) throw new Error("SUBGRAPH_URL not configured");

  const res = await fetch(SUBGRAPH_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ query, variables }),
  });

  const json = (await res.json()) as { data: T; errors?: { message: string }[] };
  if (json.errors?.length) {
    throw new Error(`Subgraph error: ${json.errors.map((e) => e.message).join(", ")}`);
  }
  return json.data;
}

export const ACCOUNT_DETAIL_QUERY = `
  query AccountDetail($address: ID!) {
    account(id: $address) {
      id
      address
      credentialId
      pubKeyX
      pubKeyY
      deployedAtTimestamp
      transactionCount
      sponsoredGasTotal
      tokenGasTotal
      ownerCount
      owners(where: { active: true }, orderBy: addedAtTimestamp, orderDirection: asc) {
        id
        credentialId
        addedAtTimestamp
        active
      }
      transactions(orderBy: timestamp, orderDirection: desc, first: 20) {
        id
        to
        value
        isBatch
        batchSize
        timestamp
        txHash
      }
      sponsoredOpsETH(orderBy: timestamp, orderDirection: desc, first: 10) {
        id
        actualGasCost
        timestamp
        txHash
      }
      sponsoredOpsToken(orderBy: timestamp, orderDirection: desc, first: 10) {
        id
        token
        tokenAmount
        ethCost
        timestamp
        txHash
      }
    }
  }
`;

export const PROTOCOL_STATS_QUERY = `
  query ProtocolStats {
    protocolStats(id: "global") {
      totalAccounts
      totalTransactions
      totalSponsoredETH
      totalSponsoredToken
    }
    dailySnapshots(orderBy: date, orderDirection: desc, first: 30) {
      date
      newAccounts
      transactions
      sponsoredOpsETH
      sponsoredOpsToken
    }
  }
`;

export const SUPPORTED_TOKENS_QUERY = `
  query SupportedTokens {
    tokenPaymentStats(orderBy: totalAmount, orderDirection: desc, first: 20) {
      token
      totalAmount
      totalEthEquivalent
      useCount
    }
  }
`;
