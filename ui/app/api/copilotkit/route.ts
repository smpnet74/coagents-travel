import { NextRequest } from "next/server";
import {
  CopilotRuntime,
  OpenAIAdapter,
  copilotRuntimeNextJSAppRouterEndpoint,
  langGraphPlatformEndpoint,
  copilotKitEndpoint,
} from "@copilotkit/runtime";
import OpenAI from "openai";

// Lazy-load OpenAI client to avoid build-time initialization issues
function createOpenAIAdapter() {
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY!
  });
  return new OpenAIAdapter({ openai } as any);
}
const langsmithApiKey = process.env.LANGSMITH_API_KEY as string;

export const POST = async (req: NextRequest) => {
  // Check for required environment variables at runtime
  if (!process.env.OPENAI_API_KEY || process.env.OPENAI_API_KEY === 'build-time-placeholder') {
    return new Response(
      JSON.stringify({ error: 'OPENAI_API_KEY environment variable is required' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const searchParams = req.nextUrl.searchParams;
  const deploymentUrl = searchParams.get("lgcDeploymentUrl");

  const remoteEndpoint = deploymentUrl
    ? langGraphPlatformEndpoint({
        deploymentUrl,
        langsmithApiKey,
        agents: [
          {
            name: "travel",
            description:
              "This agent helps the user plan and manage their trips",
          },
        ],
      })
    : copilotKitEndpoint({
        url:
          process.env.REMOTE_ACTION_URL || "http://localhost:8000/copilotkit",
      });

  const runtime = new CopilotRuntime({
    remoteEndpoints: [remoteEndpoint],
  });

  const { handleRequest } = copilotRuntimeNextJSAppRouterEndpoint({
    runtime,
    serviceAdapter: createOpenAIAdapter(),
    endpoint: "/api/copilotkit",
  });

  return handleRequest(req);
};
