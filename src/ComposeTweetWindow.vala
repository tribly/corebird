/*  This file is part of corebird.
 *
 *  corebird is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  corebird is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with corebird.  If not, see <http://www.gnu.org/licenses/>.
 */


using Gtk;

[GtkTemplate (ui = "/org/baedert/corebird/ui/compose-window.ui")]
class ComposeTweetWindow : Gtk.Window {
  private static const int MAX_TWEET_LENGTH = 140;
  [GtkChild]
  private Gtk.Image avatar_image;
  [GtkChild]
  private Gtk.Button add_image_button;
  [GtkChild]
  private Gtk.Grid main_grid;
  [GtkChild]
  private Gtk.TextView tweet_text;
  [GtkChild]
  private Gtk.Label length_label;
  [GtkChild]
  private Gtk.Button send_button;
  private PixbufButton media_image = new PixbufButton ();
  private string media_uri;
  private uint media_count = 0;
  private unowned Account account;
  private unowned Tweet answer_to;


  public ComposeTweetWindow(Window? parent, Account acc, Tweet? answer_to = null,
                            Gtk.Application? app = null) {
    this.account = acc;
    this.answer_to = answer_to;
    avatar_image.set_from_pixbuf (acc.avatar);
    length_label.label = MAX_TWEET_LENGTH.to_string ();

    if (parent != null) {
      this.set_transient_for (parent);
    }

    media_image.set_halign(Align.CENTER);
    media_image.set_valign(Align.START);

    media_image.clicked.connect (() => {
      media_image.set_visible(false);
      media_count--;
      if(media_count <= Twitter.get_max_media_per_upload())
        add_image_button.set_sensitive(true);
    });
    main_grid.attach (media_image, 0, 1, 1, 1);

    // Doesn't work at the moment
    add_image_button.sensitive = false;

    tweet_text.buffer.changed.connect (() => {
      TextIter cursor_iter, back_iter, front_iter;
      tweet_text.buffer.get_iter_at_offset (out cursor_iter, tweet_text.buffer.cursor_position);
      tweet_text.buffer.get_iter_at_offset (out back_iter, tweet_text.buffer.cursor_position - 1);
      tweet_text.buffer.get_iter_at_offset (out front_iter, tweet_text.buffer.cursor_position + 1);
      string lookback;

      while (true) {
        lookback = tweet_text.buffer.get_slice (back_iter, cursor_iter, true);
        if (lookback.has_prefix ("@") || lookback.has_prefix ("\n") ||
            lookback.has_prefix (" "))
          break;


        bool start_not_reached = back_iter.backward_char ();
        if (!start_not_reached)
          break;
     }
     message (lookback);

    });
    tweet_text.buffer.changed.connect (recalc_tweet_length);


  }

  private void recalc_tweet_length () {
    TextIter start, end;
    tweet_text.buffer.get_start_iter(out start);
    tweet_text.buffer.get_end_iter(out end);
    string text = tweet_text.buffer.get_text(start, end, true);
    string[] words = text.split (" ");
    int length = 0;

    foreach (string s in words) {
      if (s.has_prefix ("http://") || s.has_prefix ("www."))
        length += 22; //TODO: Get this from Twitter
      else if (s.has_prefix ("https://"))
        length += 23; //TODO: Get this from Twitter
      else
        length += s.char_count ();
    }
    // Don't forget the n-1 whitespaces
    length += words.length - 1;

    length_label.label = (MAX_TWEET_LENGTH - length).to_string ();
    if (length > 0 && length <= MAX_TWEET_LENGTH)
      send_button.sensitive = true;
    else
      send_button.sensitive = false;


  }

  [GtkCallback]
  private void send_tweet () {
    TextIter start, end;
    tweet_text.buffer.get_start_iter(out start);
    tweet_text.buffer.get_end_iter(out end);
    string text = tweet_text.buffer.get_text(start, end, true);
    if(text.strip() == "")
      return;

    Rest.Param param;
    var call = account.proxy.new_call();
    call.set_method("POST");
    call.add_param("status", text);
    if(this.answer_to != null) {
      call.add_param("in_reply_to_status_id", answer_to.id.to_string());
    }


//    if(media_count == 0){
      call.set_function("1.1/statuses/update.json");
/*    } else {
      call.set_function("1.1/statuses/update_with_media.json");
      uint8[] content;
      try {
        GLib.File media_file = GLib.File.new_for_path(media_uri);
        media_file.load_contents(null, out content, null);
      } catch (GLib.Error e) {
        critical(e.message);
      }

      param = new Rest.Param.full("media[]", Rest.MemoryUse.COPY,
                                         content, "multipart/form-data",
                                         media_uri);
      call.add_param_full(param);
    }*/

    call.invoke_async.begin(null, (obj, res) => {
      try{
        call.invoke_async.end(res);
      } catch(GLib.Error e) {
        critical(e.message);
        Utils.show_error_dialog(e.message);
      } finally {
        this.destroy();
      }
    });
    this.visible = false;
  }

  [GtkCallback]
  private void cancel_clicked (Gtk.Widget source) {
    destroy ();
  }

  [GtkCallback]
  private void add_image_clicked () {
/*    FileChooserDialog fcd = new FileChooserDialog("Select Image", null, FileChooserAction.OPEN,
                                 Stock.CANCEL, ResponseType.CANCEL,
                                 Stock.OPEN,   ResponseType.ACCEPT);
    fcd.set_modal(true);
    FileFilter filter = new FileFilter();
    filter.add_mime_type("image/png");
    filter.add_mime_type("image/jpeg");
    filter.add_mime_type("image/gif");
    fcd.set_filter(filter);
    if(fcd.run() == ResponseType.ACCEPT){
      string file = fcd.get_filename();
      this.media_uri = file;
      try{
        media_image.set_bg(new Gdk.Pixbuf.from_file_at_size(file, 40, 40));
        media_count++;
        media_image.set_visible(true);
      }catch(GLib.Error e){critical("Loading scaled image: %s", e.message);}

      if(media_count >= Twitter.get_max_media_per_upload()){
        add_image_button.set_sensitive(false);
      }
    }
    fcd.close();*/
  }

}
