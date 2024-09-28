import pandas as pd
import streamlit as st
from streamlit_gsheets import GSheetsConnection

import datetime
import os

from langchain_openai import ChatOpenAI
from langchain_core.prompts import PromptTemplate
from langchain_core.output_parsers import StrOutputParser

st.set_page_config(page_title="Coffee Taster ☕", page_icon="☕", layout="wide")

def submit_record(coffee_grind, brew_method, coffee_weight, water_weight, water_temperature, brew_time, rating, comment):
    """
    """
    conn = st.connection("gsheets", type=GSheetsConnection)
    df = conn.read(
        ttl=0,
        usecols=['coffee_weight', 'coffee_grind', 'water_weight', 'water_temperature', 'brew_time', 'brew_method', 'rating', 'comment', 'date']
    )
    df = df.dropna(how='all')
    current_date = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    new_record = {
        "coffee_weight": [coffee_weight],
        "coffee_grind": [coffee_grind],
        "water_weight": [water_weight],
        "water_temperature": [water_temperature],
        "brew_time": [brew_time],
        "brew_method": [brew_method],
        "rating": [rating],
        "comment": [comment],
        "date": [current_date]
    }
    df = pd.concat([df, pd.DataFrame(new_record)], ignore_index=True)
    df = conn.update(
        worksheet="data",
        data=df
    )

def calc_brew_ratio(brew_method, coffee_weight):
    """
    """
    if brew_method == 'Espresso':
        ratio = '1:2'
        return ratio, coffee_weight * 2
    elif brew_method == 'Aeropress':
        ratio = '1:12.5'
        return ratio, coffee_weight * 12.5
    elif brew_method == 'Pour Over':
        ratio = '1:17'
        return ratio, coffee_weight * 17
    elif brew_method == 'Clever':
        ratio = '1:15'
        return ratio, coffee_weight * 15
    elif brew_method == 'French Press':
        ratio = '1:15'
        return ratio, coffee_weight * 15
    elif brew_method == 'Moka':
        ratio = '1:7'
        return ratio, coffee_weight * 7
    elif brew_method == 'Drip':
        ratio = 'N/A'
        return ratio, 0
    else:
        return 'N/A', 0

def extract_coffee_details(text):
    # Set up OpenAI API key
    model = ChatOpenAI(model="gpt-4o-mini")

    prompt = PromptTemplate.from_template(
        "Extract the following details from this text about coffee brewing:\n"
        "1. Coffee grind size \n"
        "2. Brew method \n"
        "3. Coffee weight in grams \n"
        "4. Water temperature \n"
        "5. Brew time in seconds \n"
        "6. Water weight in grams \n"
        "7. Rating \n"
        "8. Comment \n\n"
        "Text: {text}\n\n"
        "Provide the answer in this exact format, ensuring all values strictly adhere to the specified options:\n"
        "Coffee grind size: [integer between 1-40]\n"
        "Brew method: [Espresso|Aeropress|Pour Over|Clever|French Press|Moka|Drip]\n"
        "Coffee weight: [positive integer]\n"
        "Water temperature: [175 Green|185 White|190 Oolong|200 FrenchPress|Boil]\n"
        "Brew time: [positive integer]\n"
        "Water weight: [positive integer]\n"
        "Rating: [⭐️|⭐️⭐️|⭐️⭐️⭐️|⭐️⭐️⭐️⭐️|⭐️⭐️⭐️⭐️⭐️]\n"
        "Comment: [text]"
    )
    chain = prompt | model | StrOutputParser()
    result = chain.invoke({"text": text})
    
    lines = result.strip().split('\n')
    coffee_grind = int(lines[0].split(': ')[1]) if lines[0].split(': ')[1].isdigit() else 1
    brew_method = lines[1].split(': ')[1].strip()  # Add .strip() to remove any leading/trailing whitespace
    coffee_weight = int(''.join(filter(str.isdigit, lines[2].split(': ')[1]))) if ''.join(filter(str.isdigit, lines[2].split(': ')[1])) else 0
    water_temperature = lines[3].split(': ')[1].strip()  # Add .strip() to remove any leading/trailing whitespace
    brew_time = int(''.join(filter(str.isdigit, lines[4].split(': ')[1]))) if ''.join(filter(str.isdigit, lines[4].split(': ')[1])) else 0
    water_weight = int(''.join(filter(str.isdigit, lines[5].split(': ')[1]))) if ''.join(filter(str.isdigit, lines[5].split(': ')[1])) else 0
    rating = lines[6].split(': ')[1].strip()  # Add .strip() to remove any leading/trailing whitespace
    comment = lines[7].split(': ')[1].strip()  # Add .strip() to remove any leading/trailing whitespace
    
    return coffee_grind, brew_method, coffee_weight, water_temperature, brew_time, water_weight, rating, comment

def coffee_page():
    st.title('Coffee Taster ☕')
    st.write("Example: Pour over, boil, 18g, size 4, 50sec, 60g, 4 stars, great coffee!")

    # Request OPENAI_API_KEY from the user
    with st.sidebar:
        st.header("API Key Configuration")
        if 'OPENAI_API_KEY' not in st.session_state:
            st.session_state.OPENAI_API_KEY = None

        if st.session_state.OPENAI_API_KEY is None:
            api_key = st.text_input("Please enter your OPENAI_API_KEY", type="password")
            if api_key:
                st.session_state.OPENAI_API_KEY = api_key

    if st.session_state.OPENAI_API_KEY:
        os.environ['OPENAI_API_KEY'] = st.session_state.OPENAI_API_KEY
    if 'submitted' not in st.session_state:
        st.session_state.submitted = False

    if not st.session_state.submitted:
        with st.form(key='input_form'):
            coffee_notes = st.text_area("Describe your coffee notes", placeholder="E.g., espresso, pour over, etc...")
            submitted = st.form_submit_button('Translate')

        if submitted and coffee_notes:
            coffee_grind, brew_method, coffee_weight, water_temperature, brew_time, water_weight, rating, comment = extract_coffee_details(coffee_notes)
            st.session_state.coffee_grind = coffee_grind
            st.session_state.brew_method = brew_method
            st.session_state.coffee_weight = coffee_weight
            st.session_state.water_temperature = water_temperature
            st.session_state.brew_time = brew_time
            st.session_state.water_weight = water_weight
            st.session_state.rating = rating
            st.session_state.comment = comment
            st.session_state.submitted = True

    if st.session_state.submitted:
        st.write("Please review and edit the extracted details:")
        with st.form(key='review_form'):
            col1, col2, col3 = st.columns(3)
            with col1:
                brew_method = st.selectbox('Brew method', ['Espresso', 'Aeropress', 'Pour Over', 'Clever', 'French Press', 'Moka', 'Drip'], index=['Espresso', 'Aeropress', 'Pour Over', 'Clever', 'French Press', 'Moka', 'Drip'].index(st.session_state.brew_method))
                water_temperature = st.selectbox('Temperature', ['175 Green', '185 White', '190 Oolong', '200 FrenchPress', 'Boil'], index=['175 Green', '185 White', '190 Oolong', '200 FrenchPress', 'Boil'].index(st.session_state.water_temperature))
                coffee_weight = st.number_input('Coffee weight (g)', value=st.session_state.coffee_weight)
            with col2:
                coffee_grind = st.number_input('Grind size', min_value=1, max_value=40, value=st.session_state.coffee_grind)
                brew_time = st.number_input('Brew time (s)', value=st.session_state.brew_time)
                water_weight = st.number_input('Water weight (g)', value=st.session_state.water_weight)
            with col3:
                rating = st.selectbox('Rating', ['⭐️', '⭐️⭐️', '⭐️⭐️⭐️', '⭐️⭐️⭐️⭐️', '⭐️⭐️⭐️⭐️⭐️'], index=['⭐️', '⭐️⭐️', '⭐️⭐️⭐️', '⭐️⭐️⭐️⭐️', '⭐️⭐️⭐️⭐️⭐️'].index(st.session_state.rating))
                comment = st.text_input("Comment", value=st.session_state.comment)
            
            final_submitted = st.form_submit_button('Submit')
            
            if final_submitted:
                ratio, brew_weight = calc_brew_ratio(brew_method, coffee_weight)
                st.write(f'Ideal Brew Ratio for {brew_method} is {ratio} and should weigh {int(brew_weight)} grams.')
                submit_record(coffee_grind, brew_method, coffee_weight, water_weight, water_temperature, brew_time, rating, comment)
                st.markdown(f'''
                    ☕ You have tasted a coffee with the following characteristics:
                    - Weight (g): `{coffee_weight}`
                    - Water (g): `{water_weight}`
                    - Time (s): `{brew_time}`
                    - Temperature: `{water_temperature}`
                    - Rating: `{rating}`
                    - Grind Size: `{coffee_grind}`
                    - Method: `{brew_method}`
                    - Comment: `{comment}`
                    ''')
                st.session_state.submitted = False
                reset_button = st.form_submit_button('Start Over')
                if reset_button:
                    st.session_state.submitted = False

def main():
    coffee_page()

if __name__ == '__main__':
    main()