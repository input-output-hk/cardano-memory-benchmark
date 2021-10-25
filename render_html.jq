def render_html:
  (
    "<table border=1>\n" +
    "<tr><th>" + (["flags", "rss avg", "rss max", "heap avg", "heap max", "CentiCpuMax", "SecMutMax", "SecGC", "totaltime", "failed"] | join("</th><th>")) + "</th></tr>"
  ) +
  (. | map("<tr><td>" + ([ .flags, (.RSS.avg | floor | tostring) + "mb", (.RSS.max | floor | tostring) + "mb", (.Heap.avg | floor | tostring) + "mb", (.Heap.max | floor | tostring) + "mb", .CentiCpuMax, .SecMutMax, .SecGC, .totaltime, .failed ] | join("</td><td>")) + "</td></tr>" ) | join("\n")) +
  "\n</table>";
