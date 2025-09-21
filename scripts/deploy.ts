import "dotenv/config";
import { artifacts } from "hardhat";
import {
  createWalletClient,
  createPublicClient,
  http,
  parseUnits,
  getAddress,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";

const RPC_URL = process.env.RPC_URL!;
const CHAIN_ID = Number(process.env.CHAIN_ID!);
const PRIVATE_KEY = (process.env.PRIVATE_KEY || "").replace(/^0x/, "");

const NAME = process.env.TOKEN_NAME || "CampusCredit";
const SYMBOL = process.env.TOKEN_SYMBOL || "CAMP";
const CAP_HUMAN = process.env.TOKEN_CAP || "2000000";
const INIT_HUMAN = process.env.TOKEN_INITIAL || "1000000";

async function main() {
  if (!RPC_URL || !CHAIN_ID || !PRIVATE_KEY) throw new Error("Missing env vars");

  const { abi, bytecode } = await artifacts.readArtifact("CampusCreditV2");

  const chain = {
    id: CHAIN_ID,
    name: `didlab-${CHAIN_ID}`,
    nativeCurrency: { name: "ETH", symbol: "ETH", decimals: 18 },
    rpcUrls: { default: { http: [RPC_URL] } },
  } as const;

  const account = privateKeyToAccount(`0x${PRIVATE_KEY}`);
  const wallet = createWalletClient({ account, chain, transport: http(RPC_URL) });
  const publicClient = createPublicClient({ chain, transport: http(RPC_URL) });

  const cap = parseUnits(CAP_HUMAN, 18);
  const initialMint = parseUnits(INIT_HUMAN, 18);

  console.log("Deploying CampusCreditV2…");
  const hash = await wallet.deployContract({
    abi,
    bytecode,
    args: [NAME, SYMBOL, cap, getAddress(account.address), initialMint],
    maxPriorityFeePerGas: 2_000_000_000n, // 2 gwei
    maxFeePerGas: 20_000_000_000n, // 20 gwei
  });
  console.log("Deploy tx:", hash);

  const rcpt = await publicClient.waitForTransactionReceipt({ hash });
  console.log("Deployed at:", rcpt.contractAddress);
  console.log("Block:", rcpt.blockNumber);

  console.log(`\nAdd this to .env:\nTOKEN_ADDRESS=${rcpt.contractAddress}\n`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
