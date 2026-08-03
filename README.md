# premsantosh.github.io

Personal website and blog for Prem Santosh Udaya Shankar.

## Pages

- **Home** (`index.html`) — Welcome hero, work experience timeline, education, certifications, and impact highlights
- **Miscellaneous Musings** (`musings.html`) — Short-form thoughts and opinions
- **Research Briefs** (`briefs.html`) — Concise technical research write-ups
- **Projects** (`projects.html`) — Personal side projects
- **Off the Clock** (`hobbies.html`) — Hobby posts: cooking, cocktails, games, hikes, and other off-hours pursuits

## Stack

Plain HTML, CSS, and vanilla JS — no frameworks, no build step. Research briefs
are written in Markdown and rendered in the browser (see below).

## Research briefs (writing a new post)

Briefs live as Markdown, not HTML. You never have to touch CSS to publish one.

- `posts/<slug>.md` — the post itself (Markdown + a small frontmatter block).
- `assets/posts/<slug>/` — images and diagrams for that post (one folder per post).
- `brief.html` — the renderer. It reads `?p=<slug>`, loads `posts/<slug>.md`,
  and renders it inside the site's styled shell. You don't edit this to add posts.
- `briefs.html` — the index/listing page.

To add a post:

1. Create `posts/my-new-post.md`:

   ```markdown
   ---
   title: My New Post Title
   subtitle: Optional one-line subtitle (italic, under the title)
   description: One-line summary used for the page meta description.
   paper: https://arxiv.org/abs/0000.00000   # optional — adds a "Read the paper" button
   ---

   Write the body in **Markdown**. Use `####` for section headings and `---`
   for the divider lines between sections.
   ```

   Every field except `title` is optional. Omit `subtitle` / `paper` if you don't need them.

2. Add one `<article>` line to the list in `briefs.html`, pointing at the new slug:

   ```html
   <article onclick="window.location='brief.html?p=my-new-post'">
     <h3>My New Post Title <span class="arrow-icon"><i class="fas fa-arrow-right"></i></span></h3>
     <div class="preview">Short preview shown on the index.</div>
   </article>
   ```

That's it. Preview it with `make dev` and the post is live.

### Images and diagrams

Put image files under `assets/posts/<slug>/` and reference them from the Markdown:

```markdown
![Alt text](assets/posts/my-new-post/screenshot.png)
```

For hand-built SVG diagrams that should pick up the site font and the framed
"diagram" styling, save the `.svg` in the post's asset folder and embed it with:

```html
<figure>
  <div class="diagram" data-svg="assets/posts/my-new-post/my-diagram.svg"></div>
  <figcaption>Caption goes here.</figcaption>
</figure>
```

The renderer inlines `data-svg` diagrams so the SVG text uses the page's webfont.

## Off the Clock (hobby posts)

Hobby posts work exactly like research briefs, with their own parallel set of files:

- `hobby-posts/<slug>.md` — the post (same frontmatter format; `paper` is unused here).
- `assets/hobby-posts/<slug>/` — photos for that post (one folder per post).
- `hobby.html` — the renderer (`hobby.html?p=<slug>`).
- `hobbies.html` — the index/listing page; add one `<article>` card per post.

Photos are committed pre-resized (~1600px wide, JPEG quality ~80) to keep the
repo and page weight sensible.

## Local Development

Briefs are loaded with `fetch()`, so they only render when served over HTTP
(opening `brief.html` directly via `file://` will not load the Markdown). Use:

```bash
make dev    # starts server and opens browser at http://localhost:8080
make serve  # starts server only (PORT=8080 by default)
make serve PORT=3000  # use a custom port
```
