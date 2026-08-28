// Announce only a successful preview load; failed/blocked links keep the prompt.
const id = document.body.dataset.emailPreviewNoticeId
if (id && typeof BroadcastChannel !== "undefined") {
  const channel = new BroadcastChannel("account-email-preview")
  channel.postMessage({ type: "opened", id })
  channel.close()
}
