# Coffee Taster ☕

## Description
Coffee Taster application is the exploration of leveraging LLM to collect all the data from the user for the form submission instead of asking the user to fill out the form input fields themselves. 

It is built and deployed using the Streamlit and can easily be extended or changed. 

Data is saved in the personal Google Sheets. To setup up your own, please clone the repo and go through the tutorial below.  

## How to run

```
git clone git@github.com:aburmist/coffee.git
cd coffee

python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

streamlit run coffee.py
```

## References
* Follow the tutorial to set up private Google Sheet [Link](https://docs.streamlit.io/develop/tutorials/databases/private-gsheet)
* Use your OpenAI API Key 

## License
[MIT](https://choosealicense.com/licenses/mit/)





