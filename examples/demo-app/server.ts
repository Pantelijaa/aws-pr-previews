import {
    createServer,
    type IncomingMessage,
    type ServerResponse,
} from "node:http";

const port = Number(process.env.PORT ?? 8080);
const startedAt = new Date().toISOString();

const previewVars = (): string =>
    Object.entries(process.env)
        .filter(([key]) => key.startsWith("PR_PREVIEW_"))
        .map(([key, value]) => `<li><code>${key}</code> = ${value}</li>`)
        .join("") || "<li>not set</li>";

const handle = (req: IncomingMessage, res: ServerResponse) => {
    if (req.url === "/healthz") {
        res.writeHead(200).end("OK");
        return;
    }
    if (req.url !== "/") {
        res.writeHead(404).end();
        return;
    }
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(`
        <h1>aws-pr-previews demo</h1>
        <p>Started at ${startedAt}</p>
        <ul>${previewVars()}</ul>`);
};

createServer(handle).listen(port, "0.0.0.0", () =>
    console.log(`listening on ${port}`),
);
