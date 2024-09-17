import pandas as pd
import streamlit as st
from streamlit_gsheets import GSheetsConnection

import datetime

from langchain.llms import OpenAI
from langchain.prompts import PromptTemplate
from langchain.chains import LLMChain

import os

st.set_page_config(page_title="Coffee Taster ☕", page_icon="☕", layout="wide")

# Create a connection object
conn = st.connection("gsheets", type=GSheetsConnection)

# Set up OpenAI API key
os.environ["OPENAI_API_KEY"] = st.secrets["OPENAI_API_KEY"]

def submit(coffee_grind, brew_method, coffee_weight, water_weight, water_temperature, brew_time, rating, comment):
    df = conn.read(
        ttl=0,
        usecols=['coffee_weight', 'coffee_grind', 'water_weight', 'water_temperature', 'brew_time', 'brew_method', 'rating', 'comment', 'date']
    )
    df = df.dropna(how='all')

    # Define variables
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
    llm = OpenAI(temperature=0)
    prompt = PromptTemplate(
        input_variables=["text"],
        template="Extract the following details from this text about coffee brewing:\n"
                 "1. Coffee grind size (must be an integer between 1 and 40)\n"
                 "2. Brew method (must be exactly one of: Espresso, Aeropress, Pour Over, Clever, French Press, Moka, Drip)\n"
                 "3. Coffee weight in grams (must be a positive integer)\n"
                 "4. Water temperature (must be exactly one of: 175 Green, 185 White, 190 Oolong, 200 FrenchPress, Boil)\n"
                 "5. Brew time in seconds (must be a positive integer)\n"
                 "6. Water weight in grams (must be a positive integer)\n"
                 "7. Rating (must be exactly one of: ⭐️, ⭐️⭐️, ⭐️⭐️⭐️, ⭐️⭐️⭐️⭐️, ⭐️⭐️⭐️⭐️⭐️)\n"
                 "8. Comment (any text)\n\n"
                 "Text: {text}\n\n"
                 "Provide the answer in this exact format, ensuring all values strictly adhere to the specified options:\n"
                 "Coffee grind: [integer between 1-40]\n"
                 "Brew method: [Espresso|Aeropress|Pour Over|Clever|French Press|Moka|Drip]\n"
                 "Coffee weight: [positive integer]\n"
                 "Water temperature: [175 Green|185 White|190 Oolong|200 FrenchPress|Boil]\n"
                 "Brew time: [positive integer]\n"
                 "Water weight: [positive integer]\n"
                 "Rating: [⭐️|⭐️⭐️|⭐️⭐️⭐️|⭐️⭐️⭐️⭐️|⭐️⭐️⭐️⭐️⭐️]\n"
                 "Comment: [text]"
    )
    chain = LLMChain(llm=llm, prompt=prompt)
    result = chain.run(text)
    
    # Parse the result
    lines = result.strip().split('\n')
    coffee_grind = int(lines[0].split(': ')[1]) if lines[0].split(': ')[1].isdigit() else 0
    brew_method = lines[1].split(': ')[1]
    coffee_weight = int(''.join(filter(str.isdigit, lines[2].split(': ')[1]))) if ''.join(filter(str.isdigit, lines[2].split(': ')[1])) else 0
    water_temperature = lines[3].split(': ')[1]
    brew_time = int(''.join(filter(str.isdigit, lines[4].split(': ')[1]))) if ''.join(filter(str.isdigit, lines[4].split(': ')[1])) else 0
    water_weight = int(''.join(filter(str.isdigit, lines[5].split(': ')[1]))) if ''.join(filter(str.isdigit, lines[5].split(': ')[1])) else 0
    rating = lines[6].split(': ')[1]
    comment = lines[7].split(': ')[1]
    
    return coffee_grind, brew_method, coffee_weight, water_temperature, brew_time, water_weight, rating, comment

def description_page():
    st.title('Coffee Taster ☕')
    st.subheader('**Record your coffee using free text**')

    with st.form(key='description_form'):
        coffee_description = st.text_area("Describe your coffee notes", placeholder="E.g., espresso, pour over, etc...")
        submitted = st.form_submit_button('Submit')

    if submitted and coffee_description:
        coffee_grind, brew_method, coffee_weight, water_temperature, brew_time, water_weight, rating, comment = extract_coffee_details(coffee_description)
        st.write(f"Extracted details:\nGrind: {coffee_grind}\nMethod: {brew_method}\nWeight: {coffee_weight}g\nTemperature: {water_temperature}\nBrew time: {brew_time}s\nWater weight: {water_weight}g\nRating: {rating}\nComment: {comment}")
        
        ratio, brew_weight = calc_brew_ratio(brew_method, coffee_weight)
        st.write(f'Ideal Brew Ratio for {brew_method} is {ratio} and should weigh {int(brew_weight)} grams.')

        submit(coffee_grind, brew_method, coffee_weight, water_weight, water_temperature, brew_time, rating, comment)
        st.markdown(f'''
            ☕ You have tasted a coffee with the following characteristics:
            - Weight (g): `{coffee_weight}`
            - Water (g): `{water_weight}`
            - Time (s): `{brew_time}`
            - Temperature: `{water_temperature}`
            - Rating: `{rating}`
            - Grind: `{coffee_grind}`
            - Method: `{brew_method}`
            - Comment: `{comment}`
            ''')
    else:
        st.write('☝️ Describe your coffee!')

def manual_input_page():
    st.title('Coffee Taster ☕')
    st.subheader('**Record your coffee using form**')

    with st.form(key='manual_form'):
        col1, col2 = st.columns(2)
        with col1:
            brew_method = st.selectbox('Brew method', ['Espresso', 'Aeropress', 'Pour Over', 'Clever', 'French Press', 'Moka', 'Drip'])
            water_temperature = st.selectbox('Temperature', ['175 Green', '185 White', '190 Oolong', '200 FrenchPress', 'Boil'])
            coffee_weight = st.number_input('Coffee weight (g)')
        with col2:
            coffee_grind = st.number_input('Grind size', max_value=40, placeholder='1-40')
            brew_time = st.number_input('Brew time (s)', step=1)
            water_weight = st.number_input('Water weight (g)', step=10)
        
        rating = st.selectbox('Rating', ['⭐️', '⭐️⭐️', '⭐️⭐️⭐️', '⭐️⭐️⭐️⭐️', '⭐️⭐️⭐️⭐️⭐️'])
        comment = st.text_input("Comment", help="Coffee brand, tasting notes, etc.", placeholder="Tasting notes...")
        submitted = st.form_submit_button('Submit')

    if submitted:
        submit(coffee_grind, brew_method, coffee_weight, water_weight, water_temperature, brew_time, rating, comment)
        st.markdown(f'''
            ☕ You have tasted a coffee with the following characteristics:
            - Weight (g): `{coffee_weight}`
            - Water (g): `{water_weight}`
            - Time (s): `{brew_time}`
            - Temperature: `{water_temperature}`
            - Rating: `{rating}`
            - Grind: `{coffee_grind}`
            - Method: `{brew_method}`
            - Comment: `{comment}`
            ''')
    else:
        st.write('☝️ Record coffee!')

def main():
    st.sidebar.title("Select input appraoch")
    page = st.sidebar.radio("", ["Free text input", "Form input"])
    if page == "Free text input":
        description_page()
    elif page == "Form input":
        manual_input_page()

if __name__ == '__main__':
    main()