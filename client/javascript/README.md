## Javascript example client

This is just simple "pseudo" code, feel free to customize code and replace `success_info(response)`,
`handle_redirect(this.redirect_to)`, `reload_page()`
and other function with your specific functions.

<br />

### Example usage 

```javascript
// just execute action and trigger success_info by default
Api(path, opts)

// silent execute, silent function will supress success_info(msg) triggrer
Api(path, opts).silent()

// trigger info and custom function on success
Api(path, opts).done(function() { ... })

// silent and redirect on sucess
Api(path, opts).silent().redirect(path)

// silent on success, custom error func
Api(path, opts).silent().error(error_func)
```