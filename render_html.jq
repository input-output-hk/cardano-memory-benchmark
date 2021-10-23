def render_html:
  "<table>\n" + (. | map("<tr><td>" + ([ .flags, .failed ] | join("</td><td>")) + "</td></tr>" ) | join("\n")) + "\n</table>";
