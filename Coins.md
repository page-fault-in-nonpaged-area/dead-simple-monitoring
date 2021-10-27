# dead-simple-monitoring

## To add a coin to crypto dashboard

Steps:

1. Click to open the [CoinGecko supported list](https://api.coingecko.com/api/v3/coins/list?include_platform=false) to find your target coin (warning: long) 

2. Check to make sure your coin exists (ctrl+f will work in most browsers). Take note of the **id** of your coin. For example, ctrl+f [catgirl](https://www.coingecko.com/en/coins/catgirl) will give you `{"id":"catgirl","symbol":"catgirl","name":"Catgirl"}`. Take note of `"id":"catgirl"`.

2. Open `./scripts/exporters/crypto/config.yml`. Continuing with our previous example, we add catgirl to the end of the file:

```
    - Id:     dogecoin
      Ticker: doge

    - Id:     catgirl
      Ticker: catgirl
```

- Please remember that id must match from the CoinGecko supported list. Indentation should also match previous entries. Ticker name isn't important now as it's unimplemented.

4. Re-run `./scripts/demo.sh` in terminal to reload your changes.