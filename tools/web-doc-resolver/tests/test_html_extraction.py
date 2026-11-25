from scripts.utils import extract_text_from_html


def test_extract_basic_html():
    html = "<div><p>Hello</p><span>World</span></div>"
    text = extract_text_from_html(html)
    assert "Hello" in text
    assert "World" in text
    # p tag triggers double newline
    assert "Hello\n\nWorld" in text


def test_exclude_script_and_style():
    html = """
    <html>
    <head>
        <style>.hide { display: none; }</style>
        <script>alert('hidden');</script>
    </head>
    <body>
        <p>Visible</p>
    </body>
    </html>
    """
    text = extract_text_from_html(html)
    assert "Visible" in text
    assert ".hide" not in text
    assert "alert" not in text


def test_block_tags_newlines():
    html = "<h1>Title</h1><div>Div</div><p>Para</p><ul><li>Item 1</li><li>Item 2</li></ul>"
    text = extract_text_from_html(html)
    assert "Title" in text
    assert "Div" in text
    assert "Para" in text
    assert "Item 1" in text
    assert "Item 2" in text
    # The current implementation might add more newlines than strictly necessary but ensures separation
    assert "Title\n\nDiv" in text or "Title\nDiv" in text
    assert "Item 1\n\nItem 2" in text


def test_code_formatting():
    html = "<p>Use <code>git status</code></p><pre>def main():\n    pass</pre>"
    text = extract_text_from_html(html)
    assert "Use `git status`" in text
    # Pre tag adds \n\n```\n and ends with \n```\n\n
    assert "```\ndef main():\n    pass\n```" in text


def test_whitespace_normalization():
    html = "<p>Too   many    spaces</p>"
    text = extract_text_from_html(html)
    assert "Too many spaces" in text


def test_newline_normalization():
    html = "<div>Line 1</div><br><br><br><div>Line 2</div>"
    text = extract_text_from_html(html)
    # Consecutive newlines should be limited to two
    assert "Line 1\n\nLine 2" in text
    assert "\n\n\n" not in text


def test_nested_div_p():
    html = "<div>Outer<div>Inner<p>Paragraph</p></div></div>"
    text = extract_text_from_html(html)
    assert "Outer" in text
    assert "Inner" in text
    assert "Paragraph" in text
