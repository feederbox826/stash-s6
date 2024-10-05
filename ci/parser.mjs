import axios from 'axios';
import promises from 'fs/promises';
import fs from 'fs';

const TARGET_BRANCH = process.env.TARGET_BRANCH || 'issues/live-transcode-issues';
const TARGET_REPO = process.env.TARGET_REPO;
const WORKFLOW_NAME = process.env.WORKFLOW_NAME;
const ARTIFACT_NAME = process.env.ARTIFACT_NAME;
const GITHUB_TOKEN = fs.readFileSync('/run/secrets/GITHUB_TOKEN', 'utf8').trim();

async function downloadUrl(url) {
  const response = await axios.get(url, {
    headers: {
      Authorization: `Bearer ${GITHUB_TOKEN}`
    },
    responseType: 'stream'
  });
  await promises.writeFile(`${ARTIFACT_NAME}.zip`, response.data);
}

const ghApi = axios.create({
  baseURL: 'https://api.github.com',
  headers: {
    Authorization: `Bearer ${GITHUB_TOKEN}`,
    Accept: 'application/vnd.github+json',
    "User-Agent": "fbox826/parser",
    "X-Github-Api-Version": "2022-11-28"
  }
});

const getArtifact = () =>
  ghApi.get(`/repos/${TARGET_REPO}/actions/runs`, {
    params: {
      branch: TARGET_BRANCH,
      status: 'completed'
    }
  }).then(repo => repo.data.workflow_runs
    .find(run => run.name === WORKFLOW_NAME)
    .artifacts_url
  ).then(ghApi.get)
  .then(res => res.data.artifacts
      .find(artifact => artifact.name === ARTIFACT_NAME)
      .archive_download_url
  ).then(downloadUrl)

getArtifact();